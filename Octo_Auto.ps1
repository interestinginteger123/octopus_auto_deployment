param(
[string] $apikey='',
[string] $octopusURI='',
[string] $environment ='',
[string] $liveEnvironment= ''
) 

Add-Type -Path '~\desktop\Octopus.Client.dll' 
Import-Module Octoposh

$Header =  @{ "X-Octopus-ApiKey" = $apiKey }
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

if (-not (Test-Path env:octopusAPIKey)) { $env:octopusAPIKey += $apikey }
if (-not (Test-Path env:octopusURL)) { $env:octopusUrl += $octopusURI }

class OctopusPoshInteractor
{
    [array]$dashBoardLive
    [array]$dashBoardDeploy
    dashBoardSuport(
        [array]$a,
        [array]$b
    ){
        $this.dashBoardLive = $a
        $this.dashBoardDeploy = $b
    }
}
function Get-OctopusDashboards {
    param (
        [OctopusPoshInteractor]$octointeractor
    )
    $octointeractor.dashBoardLive = Get-OctopusDashboard -EnvironmentName $liveEnvironment
    return $octointeractor.dashBoardLive

}
function Get-Releases-Id {
    param (
        [string]$projectid,
        [string]$version
    )
    $url = ("/api/projects/$projectid/releases")        
    $releases = Invoke-RestMethod -Uri $OctopusURI$url -ContentType 'application/json' -Headers $Header -Method 'Get' -Verbose   
    $release_Ids = $releases.Items | select Id, Version | where Version -eq $version
    $release_Ids = $release_Ids.Id

    return $release_Ids
}
function Get-Projects {
    
    $dashBoardlive = Get-OctopusDashboards([OctopusPoshInteractor]$octointeractor = [OctopusPoshInteractor]::new())
    foreach ($project in $octointeractor.dashBoardLive)
    {
        if ($count -gt 4)
        {
            check_last_deployment_status $projectName
            $count = 0        
        }

        $projectName = $project.ProjectName
        $projectId = $repository.Projects.FindByName($projectName)
        $id = $projectId.Id
        $version = $project.ReleaseVersion
        $release_id = Get-Releases-Id $id $version
        Deploy-Release $release_id $id $projectName $version
        log_deployment_status $project 
        $count++
    }
}
function Deploy-Release {
    param (
        [string]$release_id,
        [string]$id,
        [string]$projectName,
        [string]$releaseversion
        )
        $enviromentDeploy = $repository.Environments.FindByName($environment)
        $DeploymentBody = @{ 
        ReleaseID = $release_id
        EnvironmentID = $enviromentDeploy.Id
            } | ConvertTo-Json
    
    Write-Host($projectName + " version: " + $releaseversion + " will be deployed to: " + $enviromentDeploy.Name  )  
    $d = Invoke-WebRequest -Uri $octopusURI/api/deployments -Method Post -Headers $Header -Body $DeploymentBody 
}

function check_last_deployment_status {
    param (
        [string]$projectname
    )
    Do {
        $dashBoardDeployProject = Get-OctopusDashboard -EnvironmentName $environment -ProjectName $projectname
        }
    While ($dashBoardDeployProject.IsCompleted -eq $false)
}

function log_deployment_status {
    param (
        [Octoposh.Model.OutputOctopusDashboardEntry]$project
    )
    if ($project.DeploymentStatus -eq 'Failed')
        {
            Write-Host($project.ProjectName + " Has failed to deploy please check")
        }
}
#region
function Get-OctopusEnvironments {
    param (
        [array]$Environments = @($environment, $liveEnvironment)
    )
    $envIDs = @()
    foreach ($environment in $Environments){
        $Env = Get-OctopusEnvironment -name $environment   
        $envIDs += $Env.id
    }
    return $envIDs
}
function Update-Dashboard-Configuration
{
    $DeploymentBody = @{ 
        IncludedEnvironmentIds = Get-OctopusEnvironments
            } | ConvertTo-Json   
    $d = Invoke-WebRequest -Uri $octopusURI/api/dashboardconfiguration -Method Put -Headers $Header -Body $DeploymentBody 
}

Update-Dashboard-Configuration $environment $liveEnvironment
Get-Projects 