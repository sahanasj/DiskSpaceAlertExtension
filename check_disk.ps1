

# Load library for Url encoding
Add-Type -AssemblyName System.Web  

# Read in configuration properties
$config = Get-Content "check_disk.cfg"

# Bag of properties passed in the config file
$properties = @{}

# Read in the properties
$config |% `
{
    [array]$line = $_ -split '='
    
    if ($line.Count -gt 1)
    {
        # Skip comment lines
        if (!($line[0].TrimStart().StartsWith("#")))
        {
            $properties[$line[0]] = $line[1]
        }
    }
}

# Create the custom event
function send_custom_event($level, $summary, $comment)
{
    $app = [System.Web.HttpUtility]::UrlEncode($properties["APPLICATION"])
    $data = "eventtype=CUSTOM&customeventtype=DiskSpace&summary=$summary&comment=$comment&severity=$level&propertynames=level&propertyvalues=$level"

    # Set up authentication for the REST requests
    $auth_header = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($properties['USER']):$($properties['PASSWORD'])"))
    $headers = @{ Authorization = $auth_header }
    $url = $properties["CONTROLLER_URL"] + "/controller/rest/applications/$app/events"

    if ($properties["DEBUG"] -match "true")
    {
        Write-Host "Sending data to create event."
        Write-Host "level: $level"
        Write-Host "summary: $summary"
        Write-Host "comment: $comment"
        Write-Host "data: $data"
        Write-Host "url: $url"
        Write-Host " "
    }

    # Send the data
    $response = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $data
}

# Compare the disk space used to the thresholds
function check_disk_used 
{
    $drives = [System.IO.DriveInfo]::GetDrives()

    $drives |% `
    {
        # Only enumerate drives with readable media
        $drive = $_

        # Ignore drives in the exclusion list (if specified)
        $skip_drive = $false
        
        $properties["EXCLUDE_LIST"] -split "\|" |% `
        {
            $filter = $_
            
            if ($drive.Name.Substring(0,1) -match $filter)
            {
                $skip_drive = $true
                break
            }
        }
        
        if ($skip_drive)
        {
            continue
        }
    
        # Ignore disk quotas; just report on total free space
        if ($drive.TotalFreeSpace -ne $null -and $drive.TotalSize -ne $null)
        {
            $filesystem = $drive.Name
        
            # Use VolumeLabel for partition
            $partition = $drive.VolumeLabel

            # Calculate used space and round to one decimal place
            $usep = ((($drive.TotalSize - $drive.TotalFreeSpace) * 100) / $drive.TotalSize).ToString("#.#")
            $hostname = [System.Environment]::MachineName    
    
            $message="Host: $hOSTNAME, Filesystem: $filesystem, Partition: $partition, Percent Used: $usep%, Application: " + $properties["APPLICATION"]

            if ($usep -gt $properties["CRITICAL_USED"])
            {
                if ($properties["DEBUG"] -match "true")
                {
                    Write-Host "ERROR: $message"
                }

                # Create the event but URL encode the data first
                $summary = [System.Web.HttpUtility]::UrlEncode("Disk space critical. $message")
                send_custom_event "ERROR" $summary ""
            }
            elseif ($usep -gt $properties["WARNING_USED"])
            {
                if ($properties["DEBUG"] -match "true")
                {
                    Write-Host "WARN: $message"
                }

                # Create the event but URL encode the data first
                $summary = [System.Web.HttpUtility]::UrlEncode("Disk space warning. $message")
                send_custom_event "WARN" $summary ""
            }
            else
            {
                if ($properties["DEBUG"] -match "true")
                {
                    Write-Host "Filesystem is good."
                    Write-Host " "
                }
            }
        }
    }
}

# Check the required variables are defined in diskspace.cfg
function check_variables
{
    "WARNING_USED,CRITICAL_USED,CONTROLLER_URL,USER,PASSWORD,APPLICATION,MINUTE_FREQUENCY" -split ',' |% `
    {
        if ($properties["DEBUG"] -match "true")
        {
            Write-Host "$($_)=$($properties[$_])"
        }

        if (!($properties.ContainsKey($_)))
        {
            Write-Host "$_ variable is required. Please specify this in a file named diskspace.cfg that is in the same folder as this script."
            return
        }
    }
}

function main
{
    check_variables

    [DateTime]$run_at = [DateTime]::Now.AddSeconds(-1)

    while ($true)
    {
        if ([DateTime]::Now -gt $run_at)
        {
            # Trigger at the same number of seconds each minute
            $run_at = $run_at.AddMinutes(1)
        
            check_disk_used
        }

        # Spin for 5s
        [System.Threading.Thread]::Sleep(5000)
    }
}

# Run the main script
main

