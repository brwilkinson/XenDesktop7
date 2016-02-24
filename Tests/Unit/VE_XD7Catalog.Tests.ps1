$here = Split-Path -Parent $MyInvocation.MyCommand.Path;
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.ps1', '')
$moduleRoot = Split-Path -Path (Split-Path -Path $here -Parent) -Parent;
Import-Module (Join-Path $moduleRoot -ChildPath "\DSCResources\$sut\$sut.psm1") -Force;

InModuleScope $sut {

    function Get-BrokerCatalog { }

    Describe 'XenDesktop7\VE_XD7Catalog' {

        $testCatalog = @{
            Name = 'Test Catalog';
            Allocation = 'Permanent'; # Permanent, Random, Static
            Provisioning = 'MCS'; # Manual, PVS, MCS
            Persistence = 'PVD'; # Discard, Local, PVD
        }

        $stubCatalog = [PSCustomObject] @{
            Name = 'Test Catalog';
            AllocationType = 'Permanent'; # Permanent, Random, Static
            ProvisioningType = 'MCS'; # Manual, PVS, MCS
            PersistUserChanges = 'OnPvd'; # Discard, OnLocal, OnPvd
            SessionSupport = 'SingleSession'; # SingleSession, MultiSession
            Description = 'This is a test machine catalog';
            PvsAddress = $null;
            PvsDomain = $null;
        };
        $testCredentials = New-Object System.Management.Automation.PSCredential 'DummyUser', (ConvertTo-SecureString 'DummyPassword' -AsPlainText -Force);

        Context 'Get-TargetResource' {
            Mock -CommandName AssertXDModule -MockWith { };
            Mock -CommandName Add-PSSnapin -MockWith { }

            It 'Returns a System.Collections.Hashtable type' {
                Mock -CommandName Get-BrokerCatalog -MockWith { return $stubCatalog; }
                Mock -CommandName Invoke-Command -MockWith { & $ScriptBlock; }

                (Get-TargetResource @testCatalog) -is [System.Collections.Hashtable] | Should Be $true;
            }

            It 'Does not throw when machine catalog does not exist' {
                $nonexistentTestCatalog = $testCatalog.Clone();
                $nonexistentTestCatalog['Name'] = 'Nonexistent Catalog';
                Mock -CommandName Get-BrokerCatalog -ParameterFilter { $Name -eq 'Nonexistent Catalog' -and $ErrorAction -eq 'SilentlyContinue' } -MockWith { Write-Error 'Nonexistent' }
                Mock -CommandName Invoke-Command -MockWith { & $ScriptBlock; }

                { Get-TargetResource @nonexistentTestCatalog } | Should Not Throw;
            }

            It 'Invokes script block without credentials by default' {
                Mock -CommandName Invoke-Command -ParameterFilter { $Credential -eq $null -and $Authentication -eq $null } { }

                Get-TargetResource @testCatalog;

                Assert-MockCalled Invoke-Command -ParameterFilter { $Credential -eq $null -and $Authentication -eq $null } -Exactly 1 -Scope It;
            }

            It 'Invokes script block with credentials and CredSSP when specified' {
                $testCatalogWithCredentials = $testCatalog.Clone();
                $testCatalogWithCredentials['Credential'] = $testCredentials;
                Mock -CommandName Invoke-Command -ParameterFilter { $Credential -eq $testCredentials -and $Authentication -eq 'CredSSP' } { }

                Get-TargetResource @testCatalogWithCredentials;

                Assert-MockCalled Invoke-Command -ParameterFilter { $Credential -eq $testCredentials -and $Authentication -eq 'CredSSP' } -Exactly 1 -Scope It;
            }

            It 'Asserts "Citrix.Broker.Admin.V2" snapin is registered' {
                Mock -CommandName AssertXDModule -MockWith { };

                Get-TargetResource @testCatalog;

                Assert-MockCalled AssertXDModule -Scope It;
            }

        } #end context Get-TargetResource

    } #end describe XD7Catalog

} #end inmodulescope