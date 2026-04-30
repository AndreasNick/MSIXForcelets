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
            "id": "<xsl:value-of select="id"/>"
			<!-- Andreas Nick 2026.04.22: executable is optional - PsfFtaCom Application entries have no child process -->
            <xsl:if test="executable">
            ,"executable": "<xsl:value-of select="executable"/>"
            </xsl:if>
            <xsl:if test="arguments">
            ,"arguments": "<xsl:value-of select="normalize-space(arguments)"/>"
            </xsl:if>
            <xsl:if test="workingDirectory">
            ,"workingDirectory": "<xsl:value-of select="normalize-space(workingDirectory)"/>"
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
            ,"scriptExecutionMode": "<xsl:value-of select="scriptExecutionMode"/>"
            </xsl:if>

            <xsl:if test="monitor">
            , "monitor" :
            {
                "executable": "<xsl:value-of select="monitor/executable"/>"
                , "arguments": "<xsl:value-of select="monitor/arguments"/>"
                <xsl:if test="monitor/asadmin">
                    , "asadmin": <xsl:value-of select="monitor/asadmin"/>
                </xsl:if>
                <xsl:if test="wait">
                    ,"wait": "<xsl:value-of select="monitor/wait"/>"
                </xsl:if>
            }
            </xsl:if>
            <xsl:if test="startScript">
                <xsl:variable name="startScriptHeader" select="startScript" />
                ,"startScript":
                {
                     "scriptPath": "<xsl:value-of select="$startScriptHeader/scriptPath"/>"
                    , "scriptArguments": "<xsl:value-of select="$startScriptHeader/scriptArguments"/>"
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
                     "scriptPath": "<xsl:value-of select="$endScriptHeader/scriptPath"/>"
                    , "scriptArguments": "<xsl:value-of select="$endScriptHeader/scriptArguments"/>"
                    
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
            "executable": "<xsl:value-of select="executable"/>"
            <xsl:if test="fixups/fixup">
            ,"fixups": [
                <xsl:for-each select="fixups/fixup">
                {
                    <xsl:variable name="dllName" select="dll" />
                    "dll": "<xsl:value-of select="dll"/>"
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
                                "traceMethod": "<xsl:value-of select="config/traceMethod"/>"
                            </xsl:if>
                            
                            <xsl:if test="config/traceLevels" >
                                <xsl:if test="config/traceMethod">
                                ,
                                </xsl:if>
                                "traceLevels":
                                {
                                    <xsl:choose>
                                        <xsl:when test="config/traceLevels/traceLevel/@level='default'">
                                            "default": "<xsl:value-of select="config/traceLevels/traceLevel"/>"
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each select="config/traceLevels/traceLevel">
                                                "<xsl:value-of select="@level"/>": "<xsl:value-of select="current()"/>"
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
                                            "default": "<xsl:value-of select="config/breakOn/break"/>"
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each select="config/breakOn/break">
                                                "<xsl:value-of select="@level"/>": "<xsl:value-of select="current()"/>"
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
                            ,"overrideCOW": "<xsl:value-of select="config/overrideCOW"/>"
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
                                "name": "<xsl:value-of select="name"/>",
                                "filepath": "<xsl:value-of select="filepath"/>"
                                <xsl:if test="architecture">
                                ,"architecture": "<xsl:value-of select="architecture"/>"
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
                                "type": "<xsl:value-of select="type"/>"
                                <xsl:if test="hive">
                                ,"hive": "<xsl:value-of select="hive"/>"
                                </xsl:if>
                                <xsl:if test="patterns/pattern">
                                ,"patterns": [
                                    <xsl:for-each select="patterns/pattern">
                                        "<xsl:value-of select="current()"/>"
                                        <xsl:if test="position()!=last()">,</xsl:if>
                                    </xsl:for-each>
                                ]
                                </xsl:if>
                                <xsl:if test="access">
                                ,"access": "<xsl:value-of select="access"/>"
                                </xsl:if>
                                <xsl:if test="key">
                                ,"key": "<xsl:value-of select="key"/>"
                                </xsl:if>
                                <xsl:if test="majorVersion">
                                ,"majorVersion": "<xsl:value-of select="majorVersion"/>"
                                ,"minorVersion": "<xsl:value-of select="minorVersion"/>"
                                ,"updateVersion": "<xsl:value-of select="updateVersion"/>"
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
                                            "base": "<xsl:value-of select="pathConfig/base"/>",
                                            "patterns": [
                                                <xsl:for-each select="pathConfig/patterns/pattern">
                                                    "<xsl:value-of select="current()"/>"
                                                    <xsl:if test="position()!=last()">,</xsl:if>
                                                </xsl:for-each>
                                            ]
											<!-- Andreas Nick 2021.02.19 -->

											<xsl:if test="pathConfig/isExclusion">
											, "isExclusion": <xsl:value-of select="pathConfig/isExclusion"/>
											</xsl:if>

											<xsl:if test="pathConfig/redirectTargetBase">
											, "redirectTargetBase": "<xsl:value-of select="pathConfig/redirectTargetBase"/>"
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
                                            "base": "<xsl:value-of select="pathConfig/base"/>",
                                            "patterns": [
                                                <xsl:for-each select="pathConfig/patterns/pattern">
                                                    "<xsl:value-of select="current()"/>"
                                                    <xsl:if test="position()!=last()">,</xsl:if>
                                                </xsl:for-each>
                                            ]
                                            <xsl:if test="pathConfig/isExclusion">
                                            , "isExclusion": <xsl:value-of select="pathConfig/isExclusion"/>
                                            </xsl:if>
                                            <xsl:if test="pathConfig/isReadOnly">
                                            , "isReadOnly": "<xsl:value-of select="pathConfig/isReadOnly"/>"
                                            </xsl:if>
                                            <xsl:if test="pathConfig/redirectTargetBase">
                                            , "redirectTargetBase": "<xsl:value-of select="pathConfig/redirectTargetBase"/>"
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
                                            "id": "<xsl:value-of select="id"/>",
                                            "relativePaths": [
                                            <xsl:for-each select="relativePaths/relativePath">
                                            {
                                                "base": "<xsl:value-of select="base"/>",
                                                "patterns": [
                                                    <xsl:for-each select="patterns/pattern">
                                                        "<xsl:value-of select="current()"/>"
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
											, "isReadOnly": "<xsl:value-of select="isReadOnly"/>"
											</xsl:if> 
											
											<xsl:if test="redirectTargetBase">
											, "redirectTargetBase": "<xsl:value-of select="redirectTargetBase"/>"
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
                            "envVariables": [
                            <xsl:for-each select="config/envVariables/envVariable">
                            {
                                "name": "<xsl:value-of select="name"/>",
                                "value": "<xsl:value-of select="value"/>"
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
    <xsl:output omit-xml-declaration="yes"/>
</xsl:stylesheet>