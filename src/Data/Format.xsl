<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:template match="configuration">
{
    <xsl:if test="enableReportError">
    "enableReportError": <xsl:value-of select="enableReportError"/>,
    </xsl:if>
    <xsl:if test="debugLevel">
    "debugLevel": <xsl:value-of select="debugLevel"/>,
    </xsl:if>
    "applications" : [
    <xsl:for-each select="applications/application">
        {
            "id": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="id"/></xsl:call-template>"
			<!-- Andreas Nick 2026.04.22: executable is optional - PsfFtaCom Application entries have no child process -->
            <xsl:if test="executable">
            ,"executable": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="executable"/></xsl:call-template>"
            </xsl:if>
            <xsl:if test="arguments">
            ,"arguments": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="normalize-space(arguments)"/></xsl:call-template>"
            </xsl:if>
            <xsl:if test="workingDirectory">
            ,"workingDirectory": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="normalize-space(workingDirectory)"/></xsl:call-template>"
            </xsl:if>
			<!-- Andreas Nick 2026.04.22: Tim Mangan PSF - preventMultipleInstances, terminateChildren -->
            <xsl:if test="preventMultipleInstances">
            ,"preventMultipleInstances": <xsl:value-of select="preventMultipleInstances"/>
            </xsl:if>
            <xsl:if test="terminateChildren">
            ,"terminateChildren": <xsl:value-of select="terminateChildren"/>
            </xsl:if>
			<!-- Andreas Nick 2026.04.22: Tim Mangan PSF - hasShellVerbs enables PsfFtaCom shell extension surrogate -->
            <xsl:if test="hasShellVerbs">
            ,"hasShellVerbs": <xsl:value-of select="hasShellVerbs"/>
            </xsl:if>
            <xsl:if test="stopOnScriptError">
            ,"stopOnScriptError": <xsl:value-of select="stopOnScriptError"/>
            </xsl:if>
		    
			<!-- Andreas Nick 2021.03.10 -->
            <xsl:if test="scriptExecutionMode">
            ,"scriptExecutionMode": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="scriptExecutionMode"/></xsl:call-template>"
            </xsl:if>

            <xsl:if test="monitor">
            , "monitor" :
            {
                "executable": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="monitor/executable"/></xsl:call-template>"
                , "arguments": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="monitor/arguments"/></xsl:call-template>"
                <xsl:if test="monitor/asadmin">
                    , "asadmin": <xsl:value-of select="monitor/asadmin"/>
                </xsl:if>
                <xsl:if test="monitor/wait">
                    ,"wait": <xsl:value-of select="monitor/wait"/>
                </xsl:if>
            }
            </xsl:if>
            <xsl:if test="startScript">
                <xsl:variable name="startScriptHeader" select="startScript" />
                ,"startScript":
                {
                     "scriptPath": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="$startScriptHeader/scriptPath"/></xsl:call-template>"
                    , "scriptArguments": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="$startScriptHeader/scriptArguments"/></xsl:call-template>"
                    <xsl:if test="$startScriptHeader/runInVirtualEnvironment">
                    , "runInVirtualEnvironment": <xsl:value-of select="$startScriptHeader/runInVirtualEnvironment"/>
                    </xsl:if>
                    <xsl:if test="$startScriptHeader/runOnce">
                    , "runOnce": <xsl:value-of select="$startScriptHeader/runOnce"/>
                    </xsl:if>
					<!-- Andreas Nick 2021.03.10 -->
                    <xsl:if test="$startScriptHeader/showWindow">
                    , "showWindow": <xsl:value-of select="$startScriptHeader/showWindow"/>
                    </xsl:if>
                    <xsl:if test="$startScriptHeader/waitForScriptToFinish">
                    , "waitForScriptToFinish": <xsl:value-of select="$startScriptHeader/waitForScriptToFinish"/>
                    </xsl:if>
                    
                    <xsl:if test="$startScriptHeader/timeout">
                    , "timeout": <xsl:value-of select="$startScriptHeader/timeout"/>
                    </xsl:if>
                }
            </xsl:if>
            <xsl:if test="endScript">
            ,
                <xsl:variable name="endScriptHeader" select="endScript" />
                "endScript":
                {
                     "scriptPath": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="$endScriptHeader/scriptPath"/></xsl:call-template>"
                    , "scriptArguments": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="$endScriptHeader/scriptArguments"/></xsl:call-template>"
                    
                    <xsl:if test="$endScriptHeader/runInVirtualEnvironment">
                    , "runInVirtualEnvironment": <xsl:value-of select="$endScriptHeader/runInVirtualEnvironment"/>
                    </xsl:if>
                    <xsl:if test="$endScriptHeader/runOnce">
                    , "runOnce": <xsl:value-of select="$endScriptHeader/runOnce"/>
                    </xsl:if>
					<!-- Andreas Nick 2021.03.10 -->
                    <xsl:if test="$endScriptHeader/showWindow">
                    , "showWindow": <xsl:value-of select="$endScriptHeader/showWindow"/>
                    </xsl:if>					
                    <xsl:if test="$endScriptHeader/waitForScriptToFinish">
                    , "waitForScriptToFinish": <xsl:value-of select="$endScriptHeader/waitForScriptToFinish"/>
                    </xsl:if>
                    <xsl:if test="$endScriptHeader/timeout">
                    , "timeout": <xsl:value-of select="$endScriptHeader/timeout"/>
                    </xsl:if>
                }
            </xsl:if>
            
            
        }
        <xsl:if test="position()!=last()">
        ,
        </xsl:if>
    </xsl:for-each>
    ],
    "processes" : [
    <xsl:for-each select="processes/process">
        {
            "executable": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="executable"/></xsl:call-template>"
            <xsl:if test="fixups/fixup">
            ,"fixups": [
                <xsl:for-each select="fixups/fixup">
                {
                    <xsl:variable name="dllName" select="dll" />
                    "dll": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="dll"/></xsl:call-template>"
                    <xsl:if test="contains($dllName, 'WaitForDebuggerFixup')">
                        , "config" :
                        {
                            "enabled": <xsl:value-of select="config/enabled"/>
                        }
                    </xsl:if>
                    <xsl:if test="contains($dllName, 'TraceFixup')">
                        ,"config":
                        {
                            <xsl:if test="config/traceMethod">
                                "traceMethod": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="config/traceMethod"/></xsl:call-template>"
                            </xsl:if>
                            
                            <xsl:if test="config/traceLevels" >
                                <xsl:if test="config/traceMethod">
                                ,
                                </xsl:if>
                                "traceLevels":
                                {
                                    <xsl:choose>
                                        <xsl:when test="config/traceLevels/traceLevel/@level='default'">
                                            "default": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="config/traceLevels/traceLevel"/></xsl:call-template>"
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each select="config/traceLevels/traceLevel">
                                                "<xsl:call-template name="json-string"><xsl:with-param name="s" select="@level"/></xsl:call-template>": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="current()"/></xsl:call-template>"
                                                <xsl:if test="position()!=last()">
                                                    ,
                                                </xsl:if>
                                            </xsl:for-each>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                }
                            </xsl:if>
                            
                            <xsl:if test="config/breakOn">
                                , "breakOn":
                                {
                                    <xsl:choose>
                                        <xsl:when test="config/breakOn/break/@level='default'">
                                            "default": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="config/breakOn/break"/></xsl:call-template>"
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each select="config/breakOn/break">
                                                "<xsl:call-template name="json-string"><xsl:with-param name="s" select="@level"/></xsl:call-template>": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="current()"/></xsl:call-template>"
                                                <xsl:if test="position()!=last()">
                                                    ,
                                                </xsl:if>
                                            </xsl:for-each>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                }
                            </xsl:if>
                            
                            <xsl:if test="config/waitForDebugger">
                            , "waitForDebugger": <xsl:value-of select="config/waitForDebugger"/>
                            </xsl:if>
                            
                            <xsl:if test="config/traceFunctionEntry">
                                , "traceFunctionEntry": <xsl:value-of select="config/traceFunctionEntry"/>
                            </xsl:if>
                            
                            <xsl:if test="config/traceCallingModule">
                                , "traceCallingModule": <xsl:value-of select="config/traceCallingModule"/>
                            </xsl:if>
                            
                            <xsl:if test="config/ignoreDllLoad">
                                ,"ignoreDllLoad": <xsl:value-of select="config/ignoreDllLoad" />
                            </xsl:if>
                        }
                    </xsl:if>
                    <!-- Andreas Nick 2026.04.22: Tim Mangan MFR Fixup - ilvAware / overrideCOW -->
                    <!-- ilvAware is a JSON boolean (no quotes); overrideCOW remains a string. -->
                    <xsl:if test="contains($dllName, 'MFRFixup') and config/ilvAware">
                        ,"config":
                        {
                            "ilvAware": <xsl:value-of select="config/ilvAware"/>
                            ,"overrideCOW": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="config/overrideCOW"/></xsl:call-template>"
                        }
                    </xsl:if>
                    <!-- Andreas Nick 2026.04.23: DynamicLibraryFixup - forcePackageDllUse + relativeDllPaths -->
                    <xsl:if test="contains($dllName, 'DynamicLibraryFixup')">
                        ,"config":
                        {
                            "forcePackageDllUse": <xsl:value-of select="config/forcePackageDllUse"/>
                            ,"relativeDllPaths": [
                            <xsl:for-each select="config/relativeDllPaths/relativeDllPath">
                            {
                                "name": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="name"/></xsl:call-template>",
                                "filepath": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="filepath"/></xsl:call-template>"
                                <xsl:if test="architecture">
                                ,"architecture": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="architecture"/></xsl:call-template>"
                                </xsl:if>
                            }
                            <xsl:if test="position()!=last()">,</xsl:if>
                            </xsl:for-each>
                            ]
                        }
                    </xsl:if>
                    <!-- Andreas Nick 2026.04.22: RegLegacyFixups - remediation array for HKCU/HKLM access normalisation -->
                    <xsl:if test="contains($dllName, 'RegLegacyFixup')">
                        ,"config": [
                        {
                            "remediation": [
                            <xsl:for-each select="config/remediationGroup/remediation">
                            {
                                "type": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="type"/></xsl:call-template>"
                                <xsl:if test="hive">
                                ,"hive": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="hive"/></xsl:call-template>"
                                </xsl:if>
                                <xsl:if test="patterns/pattern">
                                ,"patterns": [
                                    <xsl:for-each select="patterns/pattern">
                                        "<xsl:call-template name="json-string"><xsl:with-param name="s" select="current()"/></xsl:call-template>"
                                        <xsl:if test="position()!=last()">,</xsl:if>
                                    </xsl:for-each>
                                ]
                                </xsl:if>
                                <xsl:if test="access">
                                ,"access": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="access"/></xsl:call-template>"
                                </xsl:if>
                                <xsl:if test="key">
                                ,"key": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="key"/></xsl:call-template>"
                                </xsl:if>
                                <xsl:if test="majorVersion">
                                ,"majorVersion": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="majorVersion"/></xsl:call-template>"
                                ,"minorVersion": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="minorVersion"/></xsl:call-template>"
                                ,"updateVersion": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="updateVersion"/></xsl:call-template>"
                                </xsl:if>
                            }
                            <xsl:if test="position()!=last()">,</xsl:if>
                            </xsl:for-each>
                            ]
                        }
                        ]
                    </xsl:if>
                    <xsl:if test="contains($dllName, 'FileRedirection')">
                        ,"config":
                        {
                            "redirectedPaths": {
                                <xsl:if test="config/redirectedPaths/packageRelative">
                                    "packageRelative": [
                                    <xsl:for-each select="config/redirectedPaths/packageRelative">
                                        {
                                            "base": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="pathConfig/base"/></xsl:call-template>",
                                            "patterns": [
                                                <xsl:for-each select="pathConfig/patterns/pattern">
                                                    "<xsl:call-template name="json-string"><xsl:with-param name="s" select="current()"/></xsl:call-template>"
                                                    <xsl:if test="position()!=last()">,</xsl:if>
                                                </xsl:for-each>
                                            ]
											<!-- Andreas Nick 2021.02.19 -->

											<xsl:if test="pathConfig/isExclusion">
											, "isExclusion": <xsl:value-of select="pathConfig/isExclusion"/>
											</xsl:if>

											<xsl:if test="pathConfig/isReadOnly">
											, "isReadOnly": <xsl:value-of select="pathConfig/isReadOnly"/>
											</xsl:if>

											<xsl:if test="pathConfig/redirectTargetBase">
											, "redirectTargetBase": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="pathConfig/redirectTargetBase"/></xsl:call-template>"
											</xsl:if> <!-- -->

                                        }
									     <!-- Andreas Nick 2021.02.19 -->
										 <xsl:if test="position()!=last()">,</xsl:if>
                                    </xsl:for-each>
                                    ]
                                </xsl:if>
                                <xsl:if test="config/redirectedPaths/packageDriveRelative">
                                    <xsl:if test="config/redirectedPaths/packageRelative">,</xsl:if>
                                    "packageDriveRelative": [
                                    <xsl:for-each select="config/redirectedPaths/packageDriveRelative">
                                        {
                                            "base": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="pathConfig/base"/></xsl:call-template>",
                                            "patterns": [
                                                <xsl:for-each select="pathConfig/patterns/pattern">
                                                    "<xsl:call-template name="json-string"><xsl:with-param name="s" select="current()"/></xsl:call-template>"
                                                    <xsl:if test="position()!=last()">,</xsl:if>
                                                </xsl:for-each>
                                            ]
                                            <xsl:if test="pathConfig/isExclusion">
                                            , "isExclusion": <xsl:value-of select="pathConfig/isExclusion"/>
                                            </xsl:if>
                                            <xsl:if test="pathConfig/isReadOnly">
                                            , "isReadOnly": <xsl:value-of select="pathConfig/isReadOnly"/>
                                            </xsl:if>
                                            <xsl:if test="pathConfig/redirectTargetBase">
                                            , "redirectTargetBase": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="pathConfig/redirectTargetBase"/></xsl:call-template>"
                                            </xsl:if>
                                        }
                                        <xsl:if test="position()!=last()">,</xsl:if>
                                    </xsl:for-each>
                                    ]
                                </xsl:if>
                                <xsl:if test="config/redirectedPaths/knownFolders">
                                    <xsl:if test="config/redirectedPaths/packageRelative or config/redirectedPaths/packageDriveRelative">,</xsl:if>
                                </xsl:if>
                                <xsl:if test="config/redirectedPaths/knownFolders">
                                    "knownFolders": [
                                    <xsl:for-each select="config/redirectedPaths/knownFolders/knownFolder">
                                        {
                                            "id": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="id"/></xsl:call-template>",
                                            "relativePaths": [
                                            <xsl:for-each select="relativePaths/relativePath">
                                            {
                                                "base": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="base"/></xsl:call-template>",
                                                "patterns": [
                                                    <xsl:for-each select="patterns/pattern">
                                                        "<xsl:call-template name="json-string"><xsl:with-param name="s" select="current()"/></xsl:call-template>"
                                                        <xsl:if test="position()!=last()">
                                                            ,
                                                        </xsl:if>
                                                    </xsl:for-each>
                                                ]
											<!-- Andreas Nick 2021.02.19 -->
											<xsl:if test="isExclusion">
											, "isExclusion": <xsl:value-of select="isExclusion"/>
											</xsl:if>
											
											<xsl:if test="isReadOnly">
											, "isReadOnly": <xsl:value-of select="isReadOnly"/>
											</xsl:if> 
											
											<xsl:if test="redirectTargetBase">
											, "redirectTargetBase": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="redirectTargetBase"/></xsl:call-template>"
											</xsl:if> <!-- -->
											
                                            }
                                            <xsl:if test="position()!=last()">
                                                ,
                                            </xsl:if>
                                            </xsl:for-each>
                                            ]
                                        }
                                        <xsl:if test="position()!=last()">
                                            ,
                                        </xsl:if>
                                    </xsl:for-each>
                                    ]
                                </xsl:if>
                            }
                        }
                    </xsl:if>
                    <!-- EnvVarFixup - environment variable injection -->
                    <xsl:if test="contains($dllName, 'EnvVarFixup')">
                        ,"config":
                        {
                            <!-- PSF reads "envVars"; every entry needs "useregistry" as a string (missing key = entry dropped). -->
                            "envVars": [
                            <xsl:for-each select="config/envVariables/envVariable">
                            {
                                "name": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="name"/></xsl:call-template>",
                                "value": "<xsl:call-template name="json-string"><xsl:with-param name="s" select="value"/></xsl:call-template>",
                                "useregistry": "<xsl:choose><xsl:when test="normalize-space(useregistry) != ''"><xsl:call-template name="json-string"><xsl:with-param name="s" select="normalize-space(useregistry)"/></xsl:call-template></xsl:when><xsl:otherwise>false</xsl:otherwise></xsl:choose>"
                            }
                            <xsl:if test="position()!=last()">,</xsl:if>
                            </xsl:for-each>
                            ]
                        }
                    </xsl:if>
                }
                    <xsl:if test="position()!=last()">
                        ,
                    </xsl:if>
                </xsl:for-each>
                ]
            </xsl:if>
        }
        <xsl:if test="position()!=last()">
            ,
        </xsl:if>
    </xsl:for-each>
    ]
}
    </xsl:template>
    <!-- Text output: values are written as they are (no &amp; / &lt; entities); JSON escaping is done by json-string. -->
    <xsl:output method="text" encoding="UTF-8"/>

    <!-- Escapes a value for use inside a JSON string: backslash, double quote, TAB, CR and LF.
         config.json.xml stores plain values, this is the only place they are escaped. -->
    <xsl:template name="json-string">
        <xsl:param name="s"/>
        <xsl:variable name="backslash">
            <xsl:call-template name="replace-all">
                <xsl:with-param name="text" select="string($s)"/>
                <xsl:with-param name="from" select="'\'"/>
                <xsl:with-param name="to" select="'\\'"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="quote">
            <xsl:call-template name="replace-all">
                <xsl:with-param name="text" select="string($backslash)"/>
                <xsl:with-param name="from" select="'&quot;'"/>
                <xsl:with-param name="to" select="'\&quot;'"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="tab">
            <xsl:call-template name="replace-all">
                <xsl:with-param name="text" select="string($quote)"/>
                <xsl:with-param name="from" select="'&#9;'"/>
                <xsl:with-param name="to" select="'\t'"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="cr">
            <xsl:call-template name="replace-all">
                <xsl:with-param name="text" select="string($tab)"/>
                <xsl:with-param name="from" select="'&#13;'"/>
                <xsl:with-param name="to" select="'\r'"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="replace-all">
            <xsl:with-param name="text" select="string($cr)"/>
            <xsl:with-param name="from" select="'&#10;'"/>
            <xsl:with-param name="to" select="'\n'"/>
        </xsl:call-template>
    </xsl:template>

    <!-- XSLT 1.0 string replace (recursive). -->
    <xsl:template name="replace-all">
        <xsl:param name="text"/>
        <xsl:param name="from"/>
        <xsl:param name="to"/>
        <xsl:choose>
            <xsl:when test="contains($text, $from)">
                <xsl:value-of select="substring-before($text, $from)"/>
                <xsl:value-of select="$to"/>
                <xsl:call-template name="replace-all">
                    <xsl:with-param name="text" select="substring-after($text, $from)"/>
                    <xsl:with-param name="from" select="$from"/>
                    <xsl:with-param name="to" select="$to"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$text"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>