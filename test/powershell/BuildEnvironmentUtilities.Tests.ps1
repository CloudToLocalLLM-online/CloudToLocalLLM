# Unit Tests for BuildEnvironmentUtilities.ps1
# Tests utility functions for WSL integration, logging, and cross-platform operations

BeforeAll {
    # Import the utilities script
    $UtilitiesPath = Join-Path $PSScriptRoot "..\..\scripts\powershell\BuildEnvironmentUtilities.ps1"
    . $UtilitiesPath
    
    # Mock external commands to prevent actual execution during tests
    Mock wsl { return "mocked wsl output" }
    Mock cmd { return "mocked cmd output" }
    Mock ssh { return "mocked ssh output" }
    Mock choco { return "mocked choco output" }
    Mock icacls { return "mocked icacls output" }
    Mock Add-WindowsCapability { return @{ RestartNeeded = $false } }
    
    # Mock Write-Host to capture output during tests
    Mock Write-Host { }
    
    # Set up test environment
    $Global:TestDrive = "TestDrive:"
}

Describe "Logging Functions" {
    
    Context "Write-LogInfo Function" {
        It "Should write info messages with correct format and color" {
            Write-LogInfo "Test info message"
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -eq "[INFO] Test info message" -and $ForegroundColor -eq 'Blue' 
            }
        }
    }
    
    Context "Write-LogSuccess Function" {
        It "Should write success messages with correct format and color" {
            Write-LogSuccess "Test success message"
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -eq "[SUCCESS] Test success message" -and $ForegroundColor -eq 'Green' 
            }
        }
    }
    
    Context "Write-LogWarning Function" {
        It "Should write warning messages with correct format and color" {
            Write-LogWarning "Test warning message"
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -eq "[WARNING] Test warning message" -and $ForegroundColor -eq 'Yellow' 
            }
        }
    }
    
    Context "Write-LogError Function" {
        It "Should write error messages with correct format and color" {
            Write-LogError "Test error message"
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -eq "[ERROR] Test error message" -and $ForegroundColor -eq 'Red' 
            }
        }
    }
}

Describe "WSL Integration Functions" {
    
    Context "Test-WSLAvailable Function" {
        It "Should return true when WSL is available" {
            Mock wsl { $Global:LASTEXITCODE = 0; return "Ubuntu-24.04" }
            
            $result = Test-WSLAvailable
            
            $result | Should -Be $true
        }
        
        It "Should return false when WSL is not available" {
            Mock wsl { throw "WSL not found" }
            
            $result = Test-WSLAvailable
            
            $result | Should -Be $false
        }
    }
    
    Context "Get-WSLDistributions Function" {
        It "Should return empty array when WSL is not available" {
            Mock Test-WSLAvailable { return $false }
            
            $result = Get-WSLDistributions
            
            $result | Should -BeOfType [array]
            $result.Count | Should -Be 0
        }
        
        It "Should parse WSL distribution list correctly" {
            Mock Test-WSLAvailable { return $true }
            Mock cmd { 
                return @(
                    "  NAME            STATE           VERSION",
                    "* Ubuntu-24.04    Running         2",
                    "  Ubuntu-22.04    Stopped         2"
                )
            }
            
            $result = Get-WSLDistributions
            
            $result.Count | Should -Be 2
            $result[0].Name | Should -Be "Ubuntu-24.04"
            $result[0].State | Should -Be "Running"
            $result[0].IsDefault | Should -Be $true
            $result[1].Name | Should -Be "Ubuntu-22.04"
            $result[1].State | Should -Be "Stopped"
            $result[1].IsDefault | Should -Be $false
        }
        
        It "Should handle empty WSL distribution list" {
            Mock Test-WSLAvailable { return $true }
            Mock cmd { return @("  NAME            STATE           VERSION") }
            
            $result = Get-WSLDistributions
            
            $result.Count | Should -Be 0
        }
    }
    
    Context "Test-WSLDistribution Function" {
        It "Should return true for running distribution" {
            Mock Get-WSLDistributions { 
                return @(
                    @{ Name = "Ubuntu-24.04"; State = "Running" },
                    @{ Name = "Ubuntu-22.04"; State = "Stopped" }
                )
            }
            
            $result = Test-WSLDistribution -DistroName "Ubuntu-24.04"
            
            $result | Should -Be $true
        }
        
        It "Should return false for stopped distribution" {
            Mock Get-WSLDistributions { 
                return @(
                    @{ Name = "Ubuntu-24.04"; State = "Running" },
                    @{ Name = "Ubuntu-22.04"; State = "Stopped" }
                )
            }
            
            $result = Test-WSLDistribution -DistroName "Ubuntu-22.04"
            
            $result | Should -Be $false
        }
        
        It "Should return false for non-existent distribution" {
            Mock Get-WSLDistributions { 
                return @(
                    @{ Name = "Ubuntu-24.04"; State = "Running" }
                )
            }
            
            $result = Test-WSLDistribution -DistroName "NonExistent"
            
            $result | Should -Be $false
        }
    }
    
    Context "Find-WSLDistribution Function" {
        BeforeEach {
            Mock Get-WSLDistributions { 
                return @(
                    @{ Name = "Ubuntu-24.04"; State = "Running" },
                    @{ Name = "Ubuntu-22.04"; State = "Running" },
                    @{ Name = "Debian"; State = "Running" },
                    @{ Name = "Arch"; State = "Stopped" }
                )
            }
        }
        
        It "Should prioritize Ubuntu distributions" {
            $result = Find-WSLDistribution -Purpose "Any"
            
            $result | Should -Be "Ubuntu-24.04"
        }
        
        It "Should find Ubuntu distribution for Ubuntu purpose" {
            $result = Find-WSLDistribution -Purpose "Ubuntu"
            
            $result | Should -Be "Ubuntu-24.04"
        }
        
        It "Should find Debian distribution when Ubuntu not available" {
            Mock Get-WSLDistributions { 
                return @(
                    @{ Name = "Debian"; State = "Running" },
                    @{ Name = "Arch"; State = "Running" }
                )
            }
            
            $result = Find-WSLDistribution -Purpose "Debian"
            
            $result | Should -Be "Debian"
        }
        
        It "Should return null when no suitable distribution found" {
            Mock Get-WSLDistributions { 
                return @(
                    @{ Name = "Arch"; State = "Stopped" }
                )
            }
            
            $result = Find-WSLDistribution -Purpose "Ubuntu"
            
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "Path Conversion Functions" {
    
    Context "Convert-WindowsPathToWSL Function" {
        It "Should convert C: drive path correctly" {
            $result = Convert-WindowsPathToWSL -WindowsPath "C:\Users\Test\Project"
            
            $result | Should -Be "/mnt/c/users/test/project"
        }
        
        It "Should convert D: drive path correctly" {
            $result = Convert-WindowsPathToWSL -WindowsPath "D:\Development\Code"
            
            $result | Should -Be "/mnt/d/development/code"
        }
        
        It "Should handle paths with spaces" {
            $result = Convert-WindowsPathToWSL -WindowsPath "C:\Program Files\Test App"
            
            $result | Should -Be "/mnt/c/program files/test app"
        }
    }
    
    Context "Convert-WSLPathToWindows Function" {
        It "Should convert /mnt/c path correctly" {
            $result = Convert-WSLPathToWindows -WSLPath "/mnt/c/users/test/project"
            
            $result | Should -Be "C:\users\test\project"
        }
        
        It "Should convert /mnt/d path correctly" {
            $result = Convert-WSLPathToWindows -WSLPath "/mnt/d/development/code"
            
            $result | Should -Be "D:\development\code"
        }
        
        It "Should return original path if not in /mnt format" {
            $result = Convert-WSLPathToWindows -WSLPath "/home/user/project"
            
            $result | Should -Be "/home/user/project"
        }
    }
}

Describe "WSL Command Execution Functions" {
    
    Context "Invoke-WSLCommand Function" {
        It "Should execute WSL command with correct parameters" {
            Mock wsl { return "command output" }
            
            $result = Invoke-WSLCommand -DistroName "Ubuntu-24.04" -Command "echo test" -PassThru
            
            $result | Should -Be "command output"
            Should -Invoke wsl -ParameterFilter { $args -contains "-d" -and $args -contains "Ubuntu-24.04" }
        }
        
        It "Should use default distribution when none specified" {
            Mock wsl { return "default output" }
            
            Invoke-WSLCommand -Command "echo test"
            
            Should -Invoke wsl -ParameterFilter { $args -contains "Ubuntu-24.04" }
        }
        
        It "Should handle working directory parameter" {
            Mock wsl { return "directory output" }
            Mock Convert-WindowsPathToWSL { return "/mnt/c/test" }
            
            Invoke-WSLCommand -Command "pwd" -WorkingDirectory "C:\Test"
            
            Should -Invoke wsl -ParameterFilter { $args -contains "--cd" -and $args -contains "/mnt/c/test" }
        }
        
        It "Should handle root user flag" {
            Mock wsl { return "root output" }
            
            Invoke-WSLCommand -Command "whoami" -AsRoot
            
            Should -Invoke wsl -ParameterFilter { $args -contains "-u" -and $args -contains "root" }
        }
        
        It "Should throw exception on command failure when not using PassThru" {
            Mock wsl { $Global:LASTEXITCODE = 1; return "error output" }
            
            { Invoke-WSLCommand -Command "false" } | Should -Throw "*WSL command failed*"
        }
        
        It "Should return result even on failure when using PassThru" {
            Mock wsl { $Global:LASTEXITCODE = 1; return "error output" }
            
            $result = Invoke-WSLCommand -Command "false" -PassThru
            
            $result | Should -Be "error output"
        }
    }
    
    Context "Test-WSLCommand Function" {
        It "Should return true when command exists" {
            Mock wsl { return "found" }
            
            $result = Test-WSLCommand -CommandName "git"
            
            $result | Should -Be $true
        }
        
        It "Should return false when command does not exist" {
            Mock wsl { return "missing" }
            
            $result = Test-WSLCommand -CommandName "nonexistent"
            
            $result | Should -Be $false
        }
        
        It "Should handle WSL command exceptions" {
            Mock wsl { throw "WSL error" }
            
            $result = Test-WSLCommand -CommandName "test"
            
            $result | Should -Be $false
        }
    }
}

Describe "Utility Functions" {
    
    Context "Test-Command Function" {
        It "Should return true when command exists" {
            Mock Get-Command { return @{ Name = "git" } }
            
            $result = Test-Command -CommandName "git"
            
            $result | Should -Be $true
        }
        
        It "Should return false when command does not exist" {
            Mock Get-Command { return $null }
            
            $result = Test-Command -CommandName "nonexistent"
            
            $result | Should -Be $false
        }
    }
    
    Context "Get-ProjectRoot Function" {
        It "Should return parent directory of scripts directory" {
            # Mock PSScriptRoot to simulate being in scripts/powershell
            $Script:PSScriptRoot = "C:\Project\scripts\powershell"
            
            $result = Get-ProjectRoot
            
            $result | Should -Be "C:\Project"
        }
    }
    
    Context "New-DirectoryIfNotExists Function" {
        It "Should create directory when it does not exist" {
            $testPath = Join-Path $TestDrive "NewDirectory"
            Mock Test-Path { return $false }
            Mock New-Item { return @{ FullName = $testPath } }
            
            New-DirectoryIfNotExists -Path $testPath
            
            Should -Invoke New-Item -ParameterFilter { $ItemType -eq "Directory" -and $Path -eq $testPath }
        }
        
        It "Should not create directory when it already exists" {
            $testPath = Join-Path $TestDrive "ExistingDirectory"
            Mock Test-Path { return $true }
            Mock New-Item { }
            
            New-DirectoryIfNotExists -Path $testPath
            
            Should -Not -Invoke New-Item
        }
    }
    
    Context "Get-SHA256Hash Function" {
        It "Should return hash for existing file" {
            $testFile = Join-Path $TestDrive "test.txt"
            New-Item -Path $testFile -ItemType File -Value "test content"
            Mock Get-FileHash { return @{ Hash = "ABCDEF123456" } }
            
            $result = Get-SHA256Hash -FilePath $testFile
            
            $result | Should -Be "abcdef123456"
        }
        
        It "Should throw exception for non-existent file" {
            $nonExistentFile = Join-Path $TestDrive "nonexistent.txt"
            
            { Get-SHA256Hash -FilePath $nonExistentFile } | Should -Throw "*File not found*"
        }
    }
}

Describe "SSH Integration Functions" {
    
    Context "Test-SSHConnectivity Function" {
        It "Should return true when SSH connection succeeds" {
            Mock ssh { $Global:LASTEXITCODE = 0; return "SSH_TEST_SUCCESS" }
            
            $result = Test-SSHConnectivity -VPSHost "test.example.com" -VPSUser "testuser"
            
            $result | Should -Be $true
        }
        
        It "Should return false when SSH connection fails" {
            Mock ssh { $Global:LASTEXITCODE = 1; return "Connection failed" }
            
            $result = Test-SSHConnectivity -VPSHost "test.example.com" -VPSUser "testuser"
            
            $result | Should -Be $false
        }
        
        It "Should handle SSH command exceptions" {
            Mock ssh { throw "Network error" }
            
            $result = Test-SSHConnectivity -VPSHost "test.example.com" -VPSUser "testuser"
            
            $result | Should -Be $false
        }
        
        It "Should use custom timeout parameter" {
            Mock ssh { $Global:LASTEXITCODE = 0; return "SSH_TEST_SUCCESS" }
            
            Test-SSHConnectivity -VPSHost "test.example.com" -VPSUser "testuser" -TimeoutSeconds 5
            
            Should -Invoke ssh -ParameterFilter { $args -like "*ConnectTimeout=5*" }
        }
    }
    
    Context "Set-SSHKeyPermissions Function" {
        It "Should set permissions for existing SSH key" {
            $testKey = Join-Path $TestDrive "id_rsa"
            New-Item -Path $testKey -ItemType File -Value "fake ssh key"
            Mock icacls { return "Successfully processed 1 files" }
            Mock Get-Acl { 
                $acl = New-Object System.Security.AccessControl.FileSecurity
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
                $acl.SetAccessRule($rule)
                return $acl
            }
            
            $result = Set-SSHKeyPermissions -KeyPath $testKey
            
            $result | Should -Be $true
            Should -Invoke icacls -ParameterFilter { $args -contains $testKey }
        }
        
        It "Should return false for non-existent SSH key" {
            $nonExistentKey = Join-Path $TestDrive "nonexistent_key"
            
            $result = Set-SSHKeyPermissions -KeyPath $nonExistentKey
            
            $result | Should -Be $false
        }
    }
}

Describe "Package Installation Functions" {
    
    Context "Install-Chocolatey Function" {
        It "Should skip installation when Chocolatey already exists and Force not specified" {
            Mock Test-Command { return $true }
            
            $result = Install-Chocolatey
            
            $result | Should -Be $true
            Should -Invoke Write-LogInfo -ParameterFilter { $Message -like "*already installed*" }
        }
        
        It "Should return false when not running as administrator" {
            Mock Test-Command { return $false }
            # Mock administrator check to return false
            $mockPrincipal = [PSCustomObject]@{}
            $mockPrincipal | Add-Member -MemberType ScriptMethod -Name IsInRole -Value { return $false }
            Mock Get-Variable { return @{ Value = $mockPrincipal } } -ParameterFilter { $Name -eq "principal" }
            
            $result = Install-Chocolatey
            
            $result | Should -Be $false
        }
    }
    
    Context "Install-OpenSSHClient Function" {
        It "Should skip installation when SSH already available" {
            Mock Test-Command { return $true }
            
            $result = Install-OpenSSHClient
            
            $result | Should -Be $true
            Should -Invoke Write-LogSuccess -ParameterFilter { $Message -like "*already available*" }
        }
        
        It "Should return false when not using AutoInstall" {
            Mock Test-Command { return $false }
            
            $result = Install-OpenSSHClient
            
            $result | Should -Be $false
        }
    }
}

Describe "Error Handling and Edge Cases" {
    
    Context "Invalid Parameters" {
        It "Should handle null or empty distribution names" {
            { Invoke-WSLCommand -DistroName "" -Command "test" } | Should -Not -Throw
            { Invoke-WSLCommand -DistroName $null -Command "test" } | Should -Not -Throw
        }
        
        It "Should handle invalid path formats" {
            $result = Convert-WindowsPathToWSL -WindowsPath ""
            $result | Should -Be "/mnt/"
        }
    }
    
    Context "Network and Connectivity Issues" {
        It "Should handle network timeouts gracefully" {
            Mock ssh { Start-Sleep -Seconds 1; throw "Timeout" }
            
            $result = Test-SSHConnectivity -VPSHost "unreachable.example.com" -VPSUser "test" -TimeoutSeconds 1
            
            $result | Should -Be $false
        }
    }
    
    Context "File System Issues" {
        It "Should handle permission denied errors" {
            Mock icacls { throw "Access denied" }
            
            $testKey = Join-Path $TestDrive "test_key"
            New-Item -Path $testKey -ItemType File -Force
            
            $result = Set-SSHKeyPermissions -KeyPath $testKey
            
            $result | Should -Be $false
        }
    }
}