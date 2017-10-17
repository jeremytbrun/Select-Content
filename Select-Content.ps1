<#
.SYNOPSIS
    Searches file contents for regex pattern matches.
.DESCRIPTION
    Searches file contents for regex pattern matches.
    Including the -UniquePatternGroup parameter will only return matches
    with unique group values for the indicated group index.
.EXAMPLE
    This example searches multiple logs files and returns a list of unique IP addresses found.
    Select-Content -Path "C:\Temp\Logs\LogData_Day1.txt","C:\Temp\Logs\LogData_Day5.txt" -Pattern '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' -UniquePatternGroup 0
.EXAMPLE
    This example searches a log file for donotreply email addresses and only returns the unique values based on the email domain.
    "C:\Temp\SMTPData.log" | Select-Content -Pattern '\bdonotreply@(\w+([-.]\w+)*\.\w+([-.]\w+)*)\b' -UniquePatternGroup 1 -Verbose
.EXAMPLE
    This example searches all *.log files within a directory for any email addresses.
    Get-ChildItem "C:\Temp\Logs\*" -File -Filter *.log | Select-Content -Pattern '\b\w+([-+.'']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*\b'
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>
Function Select-Content {
    [CmdletBinding(ConfirmImpact = 'Medium')]
    Param (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("FullName")]
        [String[]]
        $Path,
        
        # Param2 help description
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Pattern,

        # Param5 help description
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Nullable[int]]
        $UniquePatternGroup
    )
    
    begin {
        $StartTime = Get-Date

        if ($UniquePatternGroup -ne $null) {
            # Custom IEqualityComparer class for Hashset
            #region CSharpClass
            $Source = @"
        using System;
        
        public class myMatchComparer : System.Collections.Generic.IEqualityComparer<System.Text.RegularExpressions.Match>
        {
            // items are equal if their names and item numbers are equal.
            public bool Equals(System.Text.RegularExpressions.Match x, System.Text.RegularExpressions.Match y)
            {
                //Check whether the compared objects reference the same data.
                if (Object.ReferenceEquals(x, y))
                    return true;
        
                //Check whether any of the compared objects is null.
                if (Object.ReferenceEquals(x, null) || Object.ReferenceEquals(y, null))
                    return false;
        
                //Check whether the items' properties are equal.
                return x.Groups[$UniquePatternGroup].Value == y.Groups[$UniquePatternGroup].Value;
            }
        
            // If Equals() returns true for a pair of objects 
            // then GetHashCode() must return the same value for these objects.
            public int GetHashCode(System.Text.RegularExpressions.Match item)
            {
                //Check whether the object is null
                if (Object.ReferenceEquals(item, null)) return 0;
        
                //Calculate the hash code for the item.
                return item.Value.GetHashCode();
            }
        }
"@
            #endregion CSharpClass

            if (-not ([System.Management.Automation.PSTypeName]'myMatchComparer').Type) {            
                Add-Type -TypeDefinition $Source
            }

            $CustomComparer = New-Object myMatchComparer

            $MatchSet = New-Object "System.Collections.Generic.HashSet[System.Text.RegularExpressions.Match]" $CustomComparer
        }
        else {
            $MatchSet = New-Object System.Collections.ArrayList
        }

        $RegexEng = New-Object regex $($Pattern, 'Compiled')

        $LineCounter = 0
    }
    
    process {
        $Path | ForEach-Object {
            Write-Verbose "Parsing $_"

            $Timer = Measure-Command -Expression {
                Get-Content -Path $_ -ReadCount 1000 | ForEach-Object {
                    $MatchResult = $RegexEng.Matches($_)

                    if ($UniquePatternGroup -ne $null) {
                        $MatchSet.UnionWith([System.Text.RegularExpressions.Match[]]$MatchResult)
                    }
                    else {
                        $MatchSet.AddRange($MatchResult)
                    }

                    $LineCounter += $_.Count
                }
            }

            Write-Verbose "Parsing input took $($Timer.Hours)H:$($Timer.Minutes)M:$($Timer.Seconds)S:$($Timer.Milliseconds)MS"
        }
    }
    
    end {
        Write-Verbose "Total lines processed: $LineCounter"

        $EndTime = Get-Date
        $Runtime = $EndTime - $StartTime

        Write-Verbose "Parsing input took $($Runtime.Hours)H:$($Runtime.Minutes)M:$($Runtime.Seconds)S:$($Runtime.Milliseconds)MS"

        Write-Output $MatchSet
    }
}