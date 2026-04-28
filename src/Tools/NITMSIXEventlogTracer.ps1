#Requires -Version 5.1
<#
.SYNOPSIS
    NITMSIXEventlogTracer - WPF GUI for recording and analysing MSIX deployment events.

.DESCRIPTION
    Enables MSIX diagnostic event log channels, records events during a tracing
    session bounded by a Start/Stop action, then displays all collected events in a
    searchable, filterable WPF window with copy/save/detail capabilities.

    Run as Administrator for full diagnostic channel access (wevtutil requires elevation).
    Read-only event queries work without elevation.

.EXAMPLE
    . D:\...\NITMSIXEventlogTracer.ps1

.NOTES
    Andreas Nick, 2026 - https://www.nick-it.de
    Keyboard shortcuts: F5 = Start/Stop recording  |  Ctrl+F = Focus search  |  Escape = Clear search
#>

# Self-elevate via UAC when not running as Administrator.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        $psExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        Start-Process -FilePath $psExe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
            -Verb RunAs
        exit
    }
    # Dot-sourced without a resolvable path: continue without elevation; status bar will warn.
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ---------------------------------------------------------------------------
# Script-scope state
# ---------------------------------------------------------------------------
$script:StartTime   = $null
$script:EndTime     = $null
$script:AllEvents   = New-Object System.Collections.Generic.List[PSObject]
$script:IsRecording = $false
$script:ClockTimer  = $null

$script:Channels = @(
    'Microsoft-Windows-AppXDeployment/Operational',
    'Microsoft-Windows-AppXDeployment/Diagnostic',
    'Microsoft-Windows-AppXDeploymentServer/Operational',
    'Microsoft-Windows-AppXDeploymentServer/Diagnostic',
    'Microsoft-Windows-AppXDeployment-Server/Operational',
    'Microsoft-Windows-AppxPackaging/Operational',
    'Microsoft-Windows-AppxPackaging/Debug'
)

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Enable-MSIXChannels {
    foreach ($ch in $script:Channels) {
        try { [void](wevtutil sl $ch /e:true /q:true /ms:52428800 2>$null) } catch { }
    }
}

function Get-MSIXEvents {
    param(
        [Parameter(Mandatory = $true)] [datetime] $Since,
        [Parameter(Mandatory = $true)] [datetime] $Until
    )
    $rows = New-Object System.Collections.Generic.List[PSObject]
    foreach ($ch in $script:Channels) {
        $short = $ch -replace 'Microsoft-Windows-', ''
        try {
            $events = @(
                Get-WinEvent -LogName $ch -MaxEvents 5000 -ErrorAction Stop |
                Where-Object { $_.TimeCreated -ge $Since -and $_.TimeCreated -le $Until }
            )
        }
        catch { continue }

        foreach ($ev in $events) {
            $msg = if ($ev.Message) { $ev.Message } else { '(no message)' }
            $firstLine = ($msg -split '\r?\n')[0]
            if ($firstLine.Length -gt 220) { $firstLine = $firstLine.Substring(0, 220) + ' [...]' }

            $row = [PSCustomObject]@{
                Time         = $ev.TimeCreated
                TimeStr      = $ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss.fff')
                Level        = if ($ev.LevelDisplayName) { $ev.LevelDisplayName } else { "Level $($ev.Level)" }
                LevelN       = [int]$ev.Level
                EventId      = $ev.Id
                Channel      = $ch
                ChannelShort = $short
                MessageShort = $firstLine
                FullMessage  = $msg
                Provider     = if ($ev.ProviderName)        { $ev.ProviderName }        else { '' }
                Task         = if ($ev.TaskDisplayName)     { $ev.TaskDisplayName }     else { '' }
                Keywords     = if ($ev.KeywordsDisplayNames){ $ev.KeywordsDisplayNames -join ', ' } else { '' }
                ActivityId   = if ($ev.ActivityId)          { $ev.ActivityId.ToString() } else { '' }
            }
            $null = $rows.Add($row)
        }
    }
    return @($rows | Sort-Object Time)
}

function Get-DetailText {
    param($Row)
    if ($null -eq $Row) { return 'Select an event to see details.' }
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine("Time        : $($Row.TimeStr)")
    $null = $sb.AppendLine("Level       : $($Row.Level)  (Level code: $($Row.LevelN))")
    $null = $sb.AppendLine("Event Id    : $($Row.EventId)")
    $null = $sb.AppendLine("Channel     : $($Row.Channel)")
    $null = $sb.AppendLine("Provider    : $($Row.Provider)")
    if ($Row.Task)       { $null = $sb.AppendLine("Task        : $($Row.Task)") }
    if ($Row.Keywords)   { $null = $sb.AppendLine("Keywords    : $($Row.Keywords)") }
    if ($Row.ActivityId) { $null = $sb.AppendLine("Activity Id : $($Row.ActivityId)") }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('--- Message ---')
    $null = $sb.AppendLine($Row.FullMessage)
    return $sb.ToString()
}

function Format-EventsAsText {
    param([object[]] $Events)
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine("NIT MSIX EventlogTracer  --  Export: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    if ($script:StartTime) {
        $null = $sb.AppendLine("Recording : $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss')) - $($script:EndTime.ToString('HH:mm:ss'))")
    }
    $null = $sb.AppendLine('-' * 80)
    $null = $sb.AppendLine('')
    foreach ($ev in $Events) {
        $lvl = $ev.Level.PadRight(9)
        $null = $sb.AppendLine("$($ev.TimeStr)  [$lvl]  Id=$($ev.EventId)  $($ev.ChannelShort)")
        $null = $sb.AppendLine($ev.FullMessage)
        $null = $sb.AppendLine('')
    }
    return $sb.ToString()
}

function Format-EventsAsCsv {
    param([object[]] $Events)
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine('Time,Level,EventId,Channel,Provider,Message')
    foreach ($ev in $Events) {
        $msg = $ev.FullMessage -replace '"', '""'
        $null = $sb.AppendLine("`"$($ev.TimeStr)`",`"$($ev.Level)`",$($ev.EventId),`"$($ev.ChannelShort)`",`"$($ev.Provider)`",`"$msg`"")
    }
    return $sb.ToString()
}

function New-WindowIcon {
    # Programmatically draw the NIT MSIX logo: blue rounded square + white hex package + magnifier
    $size   = 32
    $visual = New-Object System.Windows.Media.DrawingVisual
    $dc     = $visual.RenderOpen()

    # Background - blue rounded rectangle
    $blue  = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(0, 120, 212))
    $rect  = New-Object System.Windows.Rect(0, 0, $size, $size)
    $dc.DrawRoundedRectangle($blue, $null, $rect, 5, 5)

    # White outline of hex package
    $whitePen = New-Object System.Windows.Media.Pen([System.Windows.Media.Brushes]::White, 1.5)
    $pg  = New-Object System.Windows.Media.PathGeometry
    $fig = New-Object System.Windows.Media.PathFigure
    $fig.StartPoint  = New-Object System.Windows.Point(16, 4)
    $fig.IsClosed    = $true
    $pts = @(
        (New-Object System.Windows.Point(25, 9)),
        (New-Object System.Windows.Point(25, 19)),
        (New-Object System.Windows.Point(16, 24)),
        (New-Object System.Windows.Point(7,  19)),
        (New-Object System.Windows.Point(7,  9))
    )
    foreach ($pt in $pts) {
        $null = $fig.Segments.Add((New-Object System.Windows.Media.LineSegment($pt, $true)))
    }
    $null = $pg.Figures.Add($fig)
    $dc.DrawGeometry($null, $whitePen, $pg)
    # Mid-seam of box
    $dc.DrawLine($whitePen, (New-Object System.Windows.Point(7, 9)),
                            (New-Object System.Windows.Point(16, 14)))
    $dc.DrawLine($whitePen, (New-Object System.Windows.Point(25, 9)),
                            (New-Object System.Windows.Point(16, 14)))
    $dc.DrawLine($whitePen, (New-Object System.Windows.Point(16, 14)),
                            (New-Object System.Windows.Point(16, 24)))

    # Magnifier (bottom-right overlay)
    $magnPen = New-Object System.Windows.Media.Pen([System.Windows.Media.Brushes]::White, 1.5)
    $dc.DrawEllipse($null, $magnPen, (New-Object System.Windows.Point(23, 23)), 4.5, 4.5)
    $dc.DrawLine($magnPen, (New-Object System.Windows.Point(26, 26)),
                           (New-Object System.Windows.Point(30, 30)))

    $dc.Close()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
        $size, $size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($visual)
    return $rtb
}

# Functions that reference bound controls are defined here; they access
# control variables through PowerShell's scope chain (late-bound at call time).
function Update-EventFilter {
    $text     = $TxtFilter.Text.Trim()
    $levelSel = $CboLevel.SelectedIndex   # 0=All  1=Error+Warning  2=Error only
    $pkgText  = $TxtPackageFilter.Text.Trim()

    $filtered = $script:AllEvents | Where-Object {
        $ev = $_
        $passLevel = switch ($levelSel) {
            1       { $ev.LevelN -le 3 }
            2       { $ev.LevelN -le 2 }
            default { $true }
        }
        $passText = $true
        if ($text -ne '') {
            $escaped  = [regex]::Escape($text)
            $passText = (
                $ev.TimeStr      -match $escaped -or
                $ev.Level        -match $escaped -or
                $ev.ChannelShort -match $escaped -or
                $ev.MessageShort -match $escaped -or
                $ev.FullMessage  -match $escaped -or
                ([string]$ev.EventId) -eq $text
            )
        }
        $passPkg = $true
        if ($pkgText -ne '') {
            $passPkg = ($ev.FullMessage -match [regex]::Escape($pkgText))
        }
        return ($passLevel -and $passText -and $passPkg)
    }

    $arr = @($filtered)
    $EventGrid.ItemsSource = $arr
    $total = $script:AllEvents.Count
    $shown = $arr.Count
    $TxtFilterCount.Text = "Showing $shown of $total"
    $TxtEventCount.Text  = "$shown / $total events"
}

function Show-Results {
    $RecordingPanel.Visibility = [System.Windows.Visibility]::Collapsed
    $EventGrid.Visibility      = [System.Windows.Visibility]::Visible
    $FilterBar.Visibility      = [System.Windows.Visibility]::Visible
    $BtnCopyAll.IsEnabled      = $true
    $BtnCopySelected.IsEnabled = $true
    $BtnSave.IsEnabled         = $true
    $BtnClear.IsEnabled        = $true
    Update-EventFilter
}

function Reset-ToReady {
    param([string] $SplashText = 'Ready to record MSIX deployment events')
    $script:AllEvents.Clear()
    $RecordingPanel.Visibility = [System.Windows.Visibility]::Visible
    $EventGrid.Visibility      = [System.Windows.Visibility]::Collapsed
    $FilterBar.Visibility      = [System.Windows.Visibility]::Collapsed
    $TxtSplashStatus.Text      = $SplashText
    $TxtSplashSub.Text         = "Press 'Start Recording', perform your MSIX operation, then press Stop."
    $RecordProgress.IsIndeterminate = $false
    $RecordProgress.Visibility = [System.Windows.Visibility]::Collapsed
    $RecordingDot.Visibility   = [System.Windows.Visibility]::Collapsed
    $BtnCopyAll.IsEnabled      = $false
    $BtnCopySelected.IsEnabled = $false
    $BtnSave.IsEnabled         = $false
    $BtnClear.IsEnabled        = $false
    $TxtDetails.Text           = 'Select an event to see details.'
    $TxtEventCount.Text        = ''
    $TxtFilterCount.Text       = ''
    $TxtFilter.Text            = ''
    $TxtRecordClock.Text       = ''
}

# ---------------------------------------------------------------------------
# XAML
# ---------------------------------------------------------------------------
[xml] $xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="NIT MSIX EventlogTracer"
    Height="720" Width="1120"
    MinHeight="450" MinWidth="660"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI" FontSize="12"
    Background="#F3F3F3">

  <Window.Resources>

    <!-- Shared button template with hover/press/disabled states -->
    <ControlTemplate x:Key="RoundBtnTpl" TargetType="Button">
      <Border Name="Bd"
              Background="{TemplateBinding Background}"
              BorderBrush="{TemplateBinding BorderBrush}"
              BorderThickness="{TemplateBinding BorderThickness}"
              CornerRadius="3"
              Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter TargetName="Bd" Property="Opacity" Value="0.85"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
        </Trigger>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Opacity" Value="0.35"/>
        </Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>

    <Style x:Key="DarkBtn" TargetType="Button">
      <Setter Property="Background"       Value="#2D2D3F"/>
      <Setter Property="Foreground"       Value="White"/>
      <Setter Property="BorderBrush"      Value="#444"/>
      <Setter Property="BorderThickness"  Value="1"/>
      <Setter Property="Padding"          Value="10,4"/>
      <Setter Property="Margin"           Value="0,0,4,0"/>
      <Setter Property="Cursor"           Value="Hand"/>
      <Setter Property="Template"         Value="{StaticResource RoundBtnTpl}"/>
    </Style>

    <Style x:Key="StartBtn" TargetType="Button" BasedOn="{StaticResource DarkBtn}">
      <Setter Property="Background"    Value="#0078D4"/>
      <Setter Property="BorderBrush"   Value="#005A9E"/>
      <Setter Property="FontWeight"    Value="SemiBold"/>
      <Setter Property="Padding"       Value="16,5"/>
      <Setter Property="Margin"        Value="0,0,14,0"/>
    </Style>

    <Style x:Key="SmallBtn" TargetType="Button">
      <Setter Property="Background"      Value="#E1E1E1"/>
      <Setter Property="BorderBrush"     Value="#BBBBBB"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding"         Value="8,2"/>
      <Setter Property="Margin"          Value="0,0,4,0"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="FontSize"        Value="11"/>
      <Setter Property="Template"        Value="{StaticResource RoundBtnTpl}"/>
    </Style>

    <!-- DataGrid row colouring by event level -->
    <Style x:Key="EventRowStyle" TargetType="DataGridRow">
      <Style.Triggers>
        <DataTrigger Binding="{Binding LevelN}" Value="1">
          <Setter Property="Background" Value="#FFDDDD"/>
          <Setter Property="Foreground" Value="#8B0000"/>
        </DataTrigger>
        <DataTrigger Binding="{Binding LevelN}" Value="2">
          <Setter Property="Background" Value="#FFDDDD"/>
          <Setter Property="Foreground" Value="#8B0000"/>
        </DataTrigger>
        <DataTrigger Binding="{Binding LevelN}" Value="3">
          <Setter Property="Background" Value="#FFF8DC"/>
          <Setter Property="Foreground" Value="#7B4F00"/>
        </DataTrigger>
        <DataTrigger Binding="{Binding LevelN}" Value="5">
          <Setter Property="Background" Value="#F5F5F5"/>
          <Setter Property="Foreground" Value="#555555"/>
        </DataTrigger>
      </Style.Triggers>
    </Style>

  </Window.Resources>

  <DockPanel LastChildFill="True">

    <!-- ===== Header toolbar ===== -->
    <Border DockPanel.Dock="Top" Background="#1E1E2E" Padding="10,8">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <!-- Logo + title -->
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
          <Viewbox Width="28" Height="28" Margin="0,0,9,0">
            <Canvas Width="32" Height="32">
              <Rectangle Width="32" Height="32" RadiusX="5" RadiusY="5" Fill="#0078D4"/>
              <!-- Hex package -->
              <Polygon Points="16,4 25,9 25,19 16,24 7,19 7,9"
                       Stroke="White" StrokeThickness="1.5" Fill="Transparent"/>
              <Line X1="7"  Y1="9"  X2="16" Y2="14" Stroke="White" StrokeThickness="1.5"/>
              <Line X1="25" Y1="9"  X2="16" Y2="14" Stroke="White" StrokeThickness="1.5"/>
              <Line X1="16" Y1="14" X2="16" Y2="24" Stroke="White" StrokeThickness="1.5"/>
              <!-- Magnifier -->
              <Ellipse Canvas.Left="18" Canvas.Top="19" Width="9" Height="9"
                       Stroke="White" StrokeThickness="1.5" Fill="#1E1E2E"/>
              <Line X1="26" Y1="27" X2="31" Y2="32"
                    Stroke="White" StrokeThickness="2"
                    StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
            </Canvas>
          </Viewbox>
          <TextBlock Text="NIT MSIX EventlogTracer"
                     Foreground="White" FontSize="15" FontWeight="SemiBold"
                     VerticalAlignment="Center"/>
        </StackPanel>

        <!-- Centre: Start/Stop + package filter + recording clock -->
        <StackPanel Grid.Column="1" Orientation="Horizontal"
                    HorizontalAlignment="Center" VerticalAlignment="Center">
          <Button Name="BtnStartStop" Style="{StaticResource StartBtn}"
                  Content="Start Recording" ToolTip="F5"/>
          <TextBlock Text="Package filter:" Foreground="#AAAAAA"
                     VerticalAlignment="Center" Margin="0,0,5,0"/>
          <TextBox Name="TxtPackageFilter" Width="155" Padding="6,3"
                   Background="#2D2D3F" Foreground="White" CaretBrush="White"
                   BorderBrush="#555" VerticalAlignment="Center"
                   ToolTip="Optional package name to restrict event collection (e.g. WinRAR)"/>
          <TextBlock Name="TxtRecordClock"
                     Foreground="#55BBFF" FontFamily="Consolas" FontSize="14"
                     FontWeight="SemiBold" VerticalAlignment="Center"
                     Margin="14,0,0,0" Text=""/>
        </StackPanel>

        <!-- Right: action buttons -->
        <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
          <Button Name="BtnCopyAll"      Style="{StaticResource DarkBtn}"
                  Content="Copy All"     IsEnabled="False"
                  ToolTip="Copy all visible events to clipboard"/>
          <Button Name="BtnCopySelected" Style="{StaticResource DarkBtn}"
                  Content="Copy Sel."    IsEnabled="False"
                  ToolTip="Copy selected rows to clipboard"/>
          <Button Name="BtnSave"         Style="{StaticResource DarkBtn}"
                  Content="Save..."      IsEnabled="False"
                  ToolTip="Save events to text or CSV file"/>
          <Button Name="BtnClear"        Style="{StaticResource DarkBtn}"
                  Content="Clear"        IsEnabled="False"  Margin="0"
                  ToolTip="Discard collected events and return to ready state"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- ===== Filter bar (hidden until results available) ===== -->
    <Border Name="FilterBar" DockPanel.Dock="Top" Visibility="Collapsed"
            Background="#EAEAEA" BorderBrush="#D0D0D0" BorderThickness="0,0,0,1"
            Padding="10,5">
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0" Foreground="#444"/>
        <TextBox Name="TxtFilter" Width="290" Padding="5,3"
                 BorderBrush="#BBBBBB" VerticalAlignment="Center"
                 ToolTip="Filter across all fields (Ctrl+F to focus, Escape to clear)"/>
        <Button Name="BtnClearFilter" Content=" X " Style="{StaticResource SmallBtn}"
                Margin="4,0,12,0" VerticalAlignment="Center" ToolTip="Clear filter"/>
        <Rectangle Width="1" Fill="#C0C0C0" Margin="0,2" VerticalAlignment="Stretch"/>
        <TextBlock Text="Level:" VerticalAlignment="Center" Foreground="#444" Margin="12,0,6,0"/>
        <ComboBox Name="CboLevel" Width="130" VerticalAlignment="Center" Padding="4,2"
                  SelectedIndex="0">
          <ComboBoxItem Content="All levels"/>
          <ComboBoxItem Content="Error + Warning"/>
          <ComboBoxItem Content="Error only"/>
        </ComboBox>
        <TextBlock Name="TxtFilterCount" VerticalAlignment="Center"
                   Foreground="#666" Margin="16,0,0,0" FontStyle="Italic"/>
      </StackPanel>
    </Border>

    <!-- ===== Status bar ===== -->
    <Border DockPanel.Dock="Bottom" Background="#1E1E2E" Padding="10,4">
      <Grid>
        <TextBlock Name="TxtStatus" Foreground="#9999AA" VerticalAlignment="Center"
                   Text="Ready. Run as Administrator for full diagnostic channel access."/>
        <StackPanel HorizontalAlignment="Right" Orientation="Horizontal"
                    VerticalAlignment="Center">
          <Ellipse Name="RecordingDot" Width="8" Height="8" Fill="#E81123"
                   Margin="0,0,6,0" Visibility="Collapsed"/>
          <TextBlock Name="TxtEventCount" Foreground="#9999AA"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- ===== Main content area ===== -->
    <Grid Name="MainGrid">
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="5"/>
        <RowDefinition Height="175" MinHeight="60"/>
      </Grid.RowDefinitions>

      <!-- Recording / ready splash panel -->
      <Grid Name="RecordingPanel" Grid.Row="0" Background="White">
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">

          <Viewbox Width="80" Height="80" Margin="0,0,0,18" HorizontalAlignment="Center">
            <Canvas Width="60" Height="60">
              <Ellipse Width="60" Height="60" Fill="#E5F1FB" Stroke="#0078D4" StrokeThickness="2.5"/>
              <Polygon Canvas.Left="10" Canvas.Top="10"
                       Points="20,5 33,12 33,26 20,33 7,26 7,12"
                       Fill="#0078D4"/>
              <Polygon Canvas.Left="10" Canvas.Top="10"
                       Points="20,5 33,12 20,19"
                       Fill="#004F8B"/>
              <Line Canvas.Left="10" Canvas.Top="10"
                    X1="20" Y1="19" X2="20" Y2="33"
                    Stroke="#80BFFF" StrokeThickness="1.5"/>
              <Line Canvas.Left="10" Canvas.Top="10"
                    X1="7" Y1="12" X2="20" Y2="19"
                    Stroke="#80BFFF" StrokeThickness="1.5"/>
            </Canvas>
          </Viewbox>

          <TextBlock Name="TxtSplashStatus"
                     Text="Ready to record MSIX deployment events"
                     FontSize="17" FontWeight="SemiBold"
                     Foreground="#1E1E2E" HorizontalAlignment="Center"/>

          <TextBlock Name="TxtSplashSub"
                     Text="Press 'Start Recording', perform your MSIX operation, then press Stop."
                     FontSize="12" Foreground="#666"
                     HorizontalAlignment="Center" Margin="0,7,0,0"/>

          <ProgressBar Name="RecordProgress"
                       Height="5" Width="400" Margin="0,22,0,0"
                       IsIndeterminate="False" Value="0"
                       Foreground="#0078D4" Background="#DDDDDD"
                       Visibility="Collapsed"/>

          <TextBlock Text="Monitored channels:" HorizontalAlignment="Center"
                     Foreground="#888" Margin="0,26,0,5" FontSize="11"/>
          <ItemsControl Name="ChannelList" HorizontalAlignment="Center">
            <ItemsControl.ItemTemplate>
              <DataTemplate>
                <TextBlock Text="{Binding}" Foreground="#777" FontSize="10"
                           HorizontalAlignment="Center"/>
              </DataTemplate>
            </ItemsControl.ItemTemplate>
          </ItemsControl>

        </StackPanel>
      </Grid>

      <!-- Event DataGrid (shown after collection, overlaps RecordingPanel in Row 0) -->
      <DataGrid Name="EventGrid"
                Grid.Row="0"
                Visibility="Collapsed"
                AutoGenerateColumns="False"
                IsReadOnly="True"
                SelectionMode="Extended"
                GridLinesVisibility="Horizontal"
                HeadersVisibility="Column"
                RowStyle="{StaticResource EventRowStyle}"
                AlternatingRowBackground="#F9F9F9"
                CanUserReorderColumns="True"
                CanUserResizeColumns="True"
                CanUserSortColumns="True"
                HorizontalScrollBarVisibility="Auto"
                VerticalScrollBarVisibility="Auto"
                FontFamily="Consolas" FontSize="11.5">
        <DataGrid.Columns>
          <DataGridTextColumn Header="Time"    Binding="{Binding TimeStr}"      Width="155" SortMemberPath="Time"/>
          <DataGridTextColumn Header="Level"   Binding="{Binding Level}"        Width="78"/>
          <DataGridTextColumn Header="Id"      Binding="{Binding EventId}"      Width="46"/>
          <DataGridTextColumn Header="Channel" Binding="{Binding ChannelShort}" Width="185"/>
          <DataGridTextColumn Header="Message" Binding="{Binding MessageShort}" Width="*">
            <DataGridTextColumn.ElementStyle>
              <Style TargetType="TextBlock">
                <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
              </Style>
            </DataGridTextColumn.ElementStyle>
          </DataGridTextColumn>
        </DataGrid.Columns>
        <DataGrid.ContextMenu>
          <ContextMenu>
            <MenuItem Name="MenuCopyRow"     Header="Copy Row"/>
            <MenuItem Name="MenuCopyMessage" Header="Copy Full Message"/>
            <Separator/>
            <MenuItem Name="MenuCopyAll"     Header="Copy All Visible Rows"/>
          </ContextMenu>
        </DataGrid.ContextMenu>
      </DataGrid>

      <!-- GridSplitter -->
      <GridSplitter Grid.Row="1" HorizontalAlignment="Stretch" Background="#C8C8C8"
                    ResizeBehavior="PreviousAndNext" Cursor="SizeNS"/>

      <!-- Details panel -->
      <Grid Grid.Row="2" Background="White">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#E8E8E8"
                BorderBrush="#D0D0D0" BorderThickness="0,1,0,1"
                Padding="8,4">
          <Grid>
            <TextBlock Text="Event Details" FontWeight="SemiBold" Foreground="#333"
                       VerticalAlignment="Center"/>
            <StackPanel HorizontalAlignment="Right" Orientation="Horizontal">
              <Button Name="BtnCopyDetail" Style="{StaticResource SmallBtn}"
                      Content="Copy Details" ToolTip="Copy full details to clipboard"/>
              <Button Name="BtnCopyField"  Style="{StaticResource SmallBtn}"
                      Content="Copy Field..." Margin="0"
                      ToolTip="Choose a single field to copy"/>
            </StackPanel>
          </Grid>
        </Border>
        <TextBox Grid.Row="1" Name="TxtDetails"
                 IsReadOnly="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Disabled"
                 FontFamily="Consolas" FontSize="11"
                 Padding="10" Background="White" BorderThickness="0"
                 Text="Select an event to see details."/>
      </Grid>

    </Grid>
  </DockPanel>
</Window>
'@

# ---------------------------------------------------------------------------
# Load and bind window
# ---------------------------------------------------------------------------
$reader = New-Object System.Xml.XmlNodeReader($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$BtnStartStop    = $window.FindName('BtnStartStop')
$TxtPackageFilter= $window.FindName('TxtPackageFilter')
$TxtRecordClock  = $window.FindName('TxtRecordClock')
$BtnCopyAll      = $window.FindName('BtnCopyAll')
$BtnCopySelected = $window.FindName('BtnCopySelected')
$BtnSave         = $window.FindName('BtnSave')
$BtnClear        = $window.FindName('BtnClear')
$FilterBar       = $window.FindName('FilterBar')
$TxtFilter       = $window.FindName('TxtFilter')
$BtnClearFilter  = $window.FindName('BtnClearFilter')
$CboLevel        = $window.FindName('CboLevel')
$TxtFilterCount  = $window.FindName('TxtFilterCount')
$TxtStatus       = $window.FindName('TxtStatus')
$TxtEventCount   = $window.FindName('TxtEventCount')
$RecordingDot    = $window.FindName('RecordingDot')
$RecordingPanel  = $window.FindName('RecordingPanel')
$EventGrid       = $window.FindName('EventGrid')
$RecordProgress  = $window.FindName('RecordProgress')
$TxtSplashStatus = $window.FindName('TxtSplashStatus')
$TxtSplashSub    = $window.FindName('TxtSplashSub')
$TxtDetails      = $window.FindName('TxtDetails')
$BtnCopyDetail   = $window.FindName('BtnCopyDetail')
$BtnCopyField    = $window.FindName('BtnCopyField')
$ChannelList     = $window.FindName('ChannelList')
$MenuCopyRow     = $window.FindName('MenuCopyRow')
$MenuCopyMessage = $window.FindName('MenuCopyMessage')
$MenuCopyAll     = $window.FindName('MenuCopyAll')

# Set window icon
$window.Icon = New-WindowIcon

# Populate channel list in splash panel
$ChannelList.ItemsSource = $script:Channels

# Admin warning
if (-not (Test-IsAdmin)) {
    $TxtStatus.Text       = 'Not running as Administrator -- diagnostic channels may be unavailable (read-only access only).'
    $TxtStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.Color]::FromRgb(220, 160, 0))
}

# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

$BtnStartStop.Add_Click({
    if (-not $script:IsRecording) {
        # ---- Start recording ----
        $script:IsRecording = $true
        $script:StartTime   = Get-Date
        $script:AllEvents.Clear()

        $BtnStartStop.Content    = 'Stop Recording'
        $BtnStartStop.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(209, 52, 56))

        $TxtSplashStatus.Text           = 'Recording MSIX events...'
        $TxtSplashSub.Text              = 'Perform your MSIX operation now. Press Stop when done.'
        $RecordProgress.Visibility      = [System.Windows.Visibility]::Visible
        $RecordProgress.IsIndeterminate = $true
        $RecordingDot.Visibility        = [System.Windows.Visibility]::Visible

        # Ensure splash is shown even if results were displayed before
        $RecordingPanel.Visibility = [System.Windows.Visibility]::Visible
        $EventGrid.Visibility      = [System.Windows.Visibility]::Collapsed
        $FilterBar.Visibility      = [System.Windows.Visibility]::Collapsed
        $BtnCopyAll.IsEnabled      = $false
        $BtnCopySelected.IsEnabled = $false
        $BtnSave.IsEnabled         = $false
        $BtnClear.IsEnabled        = $false

        $TxtStatus.Text       = "Recording started at $($script:StartTime.ToString('HH:mm:ss'))  --  perform your MSIX operation now."
        $TxtStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(85, 187, 255))
        $TxtEventCount.Text   = ''

        Enable-MSIXChannels

        # Clock timer: updates elapsed time every second
        $script:ClockTimer          = New-Object System.Windows.Threading.DispatcherTimer
        $script:ClockTimer.Interval = [TimeSpan]::FromSeconds(1)
        $script:ClockTimer.Add_Tick({
            if ($script:StartTime) {
                $elapsed = (Get-Date) - $script:StartTime
                $TxtRecordClock.Text = $elapsed.ToString('hh\:mm\:ss')
            }
        })
        $script:ClockTimer.Start()
    }
    else {
        # ---- Stop recording ----
        $script:EndTime     = Get-Date
        $script:IsRecording = $false

        if ($script:ClockTimer) { $script:ClockTimer.Stop(); $script:ClockTimer = $null }
        $TxtRecordClock.Text = ''

        $BtnStartStop.Content    = 'Start Recording'
        $BtnStartStop.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(0, 120, 212))

        $RecordProgress.IsIndeterminate = $false
        $RecordProgress.Visibility      = [System.Windows.Visibility]::Collapsed
        $RecordingDot.Visibility        = [System.Windows.Visibility]::Collapsed

        $TxtSplashStatus.Text = 'Collecting events, please wait...'
        $TxtSplashSub.Text    = 'Reading event channels...'
        $TxtStatus.Text       = "Collecting events from $($script:StartTime.ToString('HH:mm:ss')) to $($script:EndTime.ToString('HH:mm:ss'))..."
        $TxtStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(153, 153, 170))

        # Force UI update before the potentially slow event query
        [System.Windows.Forms.Application]::DoEvents()

        $events = Get-MSIXEvents -Since $script:StartTime -Until $script:EndTime
        foreach ($ev in $events) { $null = $script:AllEvents.Add($ev) }

        $count = $script:AllEvents.Count
        $TxtStatus.Text = "Collected $count event(s) between $($script:StartTime.ToString('HH:mm:ss')) and $($script:EndTime.ToString('HH:mm:ss'))."

        if ($count -eq 0) {
            $TxtSplashStatus.Text = 'No events found in the recording window.'
            $TxtSplashSub.Text    = 'Ensure diagnostic channels are enabled and the MSIX operation was performed during recording.'
        }
        else {
            Show-Results
        }
    }
})

$BtnCopyAll.Add_Click({
    $items = @($EventGrid.ItemsSource)
    if ($items.Count -eq 0) { return }
    [System.Windows.Clipboard]::SetText((Format-EventsAsText -Events $items))
    $TxtStatus.Text = "Copied $($items.Count) event(s) to clipboard."
})

$BtnCopySelected.Add_Click({
    $items = @($EventGrid.SelectedItems)
    if ($items.Count -eq 0) {
        $TxtStatus.Text = 'No rows selected.'
        return
    }
    [System.Windows.Clipboard]::SetText((Format-EventsAsText -Events $items))
    $TxtStatus.Text = "Copied $($items.Count) selected event(s) to clipboard."
})

$BtnSave.Add_Click({
    $dlg            = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Title      = 'Save MSIX Events'
    $dlg.Filter     = 'Text files (*.txt)|*.txt|CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    $dlg.FileName   = "MSIX_Events_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if ($dlg.ShowDialog($window) -eq $true) {
        $items = @($EventGrid.ItemsSource)
        try {
            if ($dlg.FilterIndex -eq 2) {
                Format-EventsAsCsv -Events $items | Set-Content -Path $dlg.FileName -Encoding UTF8
            }
            else {
                Format-EventsAsText -Events $items | Set-Content -Path $dlg.FileName -Encoding UTF8
            }
            $TxtStatus.Text = "Saved $($items.Count) event(s) to: $($dlg.FileName)"
        }
        catch {
            [System.Windows.MessageBox]::Show("Save failed: $_", 'NIT MSIX EventlogTracer',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    }
})

$BtnClear.Add_Click({
    $res = [System.Windows.MessageBox]::Show(
        'Discard all collected events and return to ready state?',
        'NIT MSIX EventlogTracer',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question)
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        Reset-ToReady
        $TxtStatus.Text       = 'Events cleared.'
        $TxtStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.Color]::FromRgb(153, 153, 170))
    }
})

$TxtFilter.Add_TextChanged({ Update-EventFilter })
$CboLevel.Add_SelectionChanged({ Update-EventFilter })

$BtnClearFilter.Add_Click({
    $TxtFilter.Text         = ''
    $CboLevel.SelectedIndex = 0
})

$EventGrid.Add_SelectionChanged({
    $sel = $EventGrid.SelectedItem
    $TxtDetails.Text = Get-DetailText -Row $sel
})

# Select row on right-click so context menu reflects the clicked row
$EventGrid.Add_PreviewMouseRightButtonDown({
    param($sender, $e)
    $dep = [System.Windows.DependencyObject] $e.OriginalSource
    while ($null -ne $dep -and -not ($dep -is [System.Windows.Controls.DataGridRow])) {
        $dep = [System.Windows.Media.VisualTreeHelper]::GetParent($dep)
    }
    if ($null -ne $dep) {
        $dep.IsSelected = $true
    }
})

$BtnCopyDetail.Add_Click({
    if ($TxtDetails.Text -ne 'Select an event to see details.') {
        [System.Windows.Clipboard]::SetText($TxtDetails.Text)
        $TxtStatus.Text = 'Event details copied to clipboard.'
    }
})

$BtnCopyField.Add_Click({
    $sel = $EventGrid.SelectedItem
    if ($null -eq $sel) {
        $TxtStatus.Text = 'Select an event first.'
        return
    }

    $fields = @(
        [PSCustomObject]@{ Label = 'Time';        Value = $sel.TimeStr }
        [PSCustomObject]@{ Label = 'Level';       Value = $sel.Level }
        [PSCustomObject]@{ Label = 'Event Id';    Value = [string]$sel.EventId }
        [PSCustomObject]@{ Label = 'Channel';     Value = $sel.Channel }
        [PSCustomObject]@{ Label = 'Provider';    Value = $sel.Provider }
        [PSCustomObject]@{ Label = 'Task';        Value = $sel.Task }
        [PSCustomObject]@{ Label = 'Keywords';    Value = $sel.Keywords }
        [PSCustomObject]@{ Label = 'Activity Id'; Value = $sel.ActivityId }
        [PSCustomObject]@{ Label = 'Full Message';Value = $sel.FullMessage }
    )

    $popup = New-Object System.Windows.Window
    $popup.Title                 = 'Copy Field'
    $popup.Width                 = 340
    $popup.Height                = 300
    $popup.ResizeMode            = [System.Windows.ResizeMode]::NoResize
    $popup.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $popup.Owner                 = $window
    $popup.FontFamily            = New-Object System.Windows.Media.FontFamily('Segoe UI')

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = New-Object System.Windows.Thickness(10)

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text   = 'Double-click a field to copy it:'
    $lbl.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
    $null = $sp.Children.Add($lbl)

    $lb = New-Object System.Windows.Controls.ListBox
    $lb.Height = 190
    foreach ($f in $fields) {
        $preview = $f.Value
        if ($preview.Length -gt 60) { $preview = $preview.Substring(0, 60) + '...' }
        $item         = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = "$($f.Label): $preview"
        $item.Tag     = $f.Value
        $item.ToolTip = $f.Value
        $null = $lb.Items.Add($item)
    }
    $null = $sp.Children.Add($lb)

    # Double-click copies immediately
    $lb.Add_MouseDoubleClick({
        $chosen = $lb.SelectedItem
        if ($null -ne $chosen -and $chosen.Tag -ne '') {
            [System.Windows.Clipboard]::SetText($chosen.Tag)
            $TxtStatus.Text = "Copied field '$($chosen.Content.Split(':')[0])'."
            $popup.Close()
        }
    })

    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content = 'Copy Selected Field'
    $btnCopy.Margin  = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $btnCopy.Padding = New-Object System.Windows.Thickness(10, 4, 10, 4)
    $btnCopy.Cursor  = [System.Windows.Input.Cursors]::Hand
    $btnCopy.Add_Click({
        $chosen = $lb.SelectedItem
        if ($null -ne $chosen -and $chosen.Tag -ne '') {
            [System.Windows.Clipboard]::SetText($chosen.Tag)
            $TxtStatus.Text = "Copied field '$($chosen.Content.Split(':')[0])'."
        }
        $popup.Close()
    })
    $null = $sp.Children.Add($btnCopy)

    $popup.Content = $sp
    $null = $popup.ShowDialog()
})

# Context menu handlers
$MenuCopyRow.Add_Click({
    $sel = $EventGrid.SelectedItem
    if ($null -eq $sel) { return }
    $text = "$($sel.TimeStr)  [$($sel.Level)]  Id=$($sel.EventId)  $($sel.Channel)`r`n$($sel.FullMessage)"
    [System.Windows.Clipboard]::SetText($text)
    $TxtStatus.Text = 'Row copied to clipboard.'
})

$MenuCopyMessage.Add_Click({
    $sel = $EventGrid.SelectedItem
    if ($null -eq $sel) { return }
    [System.Windows.Clipboard]::SetText($sel.FullMessage)
    $TxtStatus.Text = 'Message copied to clipboard.'
})

$MenuCopyAll.Add_Click({
    $items = @($EventGrid.ItemsSource)
    if ($items.Count -eq 0) { return }
    [System.Windows.Clipboard]::SetText((Format-EventsAsText -Events $items))
    $TxtStatus.Text = "Copied $($items.Count) visible event(s) to clipboard."
})

# Keyboard shortcuts
$window.Add_KeyDown({
    param($sender, $e)
    switch ($e.Key) {
        'F5' {
            $BtnStartStop.RaiseEvent(
                (New-Object System.Windows.RoutedEventArgs(
                    [System.Windows.Controls.Button]::ClickEvent)))
            $e.Handled = $true
        }
        'Escape' {
            if ($TxtFilter.Text -ne '') {
                $TxtFilter.Text = ''
                $e.Handled = $true
            }
        }
        'F' {
            if ($e.KeyboardDevice.Modifiers -eq [System.Windows.Input.ModifierKeys]::Control) {
                $null = $TxtFilter.Focus()
                $e.Handled = $true
            }
        }
    }
})

$window.Add_Closing({
    if ($script:ClockTimer) { $script:ClockTimer.Stop() }
})

# ---------------------------------------------------------------------------
# Show window
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
[void] $window.ShowDialog()
