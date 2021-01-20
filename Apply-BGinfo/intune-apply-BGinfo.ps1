<#
.SYNOPSIS
 This script applies BGinfo on Intune enrolled computers.

.DESCRIPTION
 Wallpaper and BGinfo can be updated/changed by non-technical users.
 No need to change codes or roll out new packages after this solution is deployed.
 This solution assumes that SharePoint libraries are synced under the default %USERPROFILE% path, e.g. C:\Users\USERNAME\
 The script creates a scheduled task. The tasks gets triggered at user logon.
 The task runs BGinfo64.exe with the required argument to apply BGinfo from a
 previously shared SharePoint library under the path %USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\
 The SharePoint library is automatically synced using a Administrative Template Intune configuration profile.
 It can take 8 hours or more for the library to sync automaticaly. Without the library BGinfo won't be applied.

.PREREQUISITES
 (A) Prepare the SharePoint library
     1) Create a SharePoint site collection https://[COMPANY].sharepoint.com/sites/doctemplates
     2) Under the default 'Shared Documents' library create a folder named "BGinfo"
     3) Sync the default document library 'Shared Documents' using OneDrive
     4) Copy extracted file (Bginfo64.exe) under the BGinfo folder (BGinfo.zip https://download.sysinternals.com/files/BGInfo.zip)
     5) Copy your wallpaper.jpg file under the BGinfo folder
     6) Using file explorer, copy the path to wallpaper.jpg synced under BGinfo folder, e.g. C:\Users\johndoe\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\wallpaper.jpg
     7) Replace "C:\Users\johndoe" with %USERPROFILE% > %USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\wallpaper.jpg (you will need this path later)


 (B) Prepare the BGinfo
     (1) Run BGinfo64.exe located under the sycned folder, format the required info to display
     (2) Click the 'Position...' button and select the appropriate location
         to display the BGinfo, e.g. bottom right corder (click the circle under 'Locate on screen').
         Select 'Compensate for Taskbar position'.
         Enter '22 inches' or the case may be for 'Limit lines to'. Click Ok.
     (3) Click the 'Background...' button. Select 'User these settings'.
         Set Wallpaper Bitmap Path (the one from the previous step) to %USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\wallpaper.jpg
         Select "Fill" for Wallpaper position.
         Check against "Make wallpaper visible behind text"
         Click Ok.
     (4) Click FILE>SAVE AS> Save the bgi file as BGinfo.bgi under the sycned BGinfo folder
     (5) You will need following paths to configure this solution
         i) %USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\wallpaper.jpg
         ii) %USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\BGinfo64.exe
         iii) %USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\BGinfo64.bgi

 (C) Add the Azure AD security group of internal staff members to the site collection's Viewer SharePoint group.

 (D) Under Intune Admin portal create a Administrative template profile (Home > Devices > Policy > Configuration Profiles. Click to create - Windows 10 and later > Administrative Templates).
     NAME =Apply BGinfo
     DESCRIPTION = Applies BGinfo on user logon
     ASSIGNMENTS = Assign to a Azure security group, where MDM user is a member
     USER CONFIGURATION \ OneDrive settings
        (1) Silently sign in users to the OneDrive sync app with their Windows credentials = Enabled
        (2) Use OneDrive Files On-Demand = Enabled
        (3) Configure team site libraries to sync automatically = Enabled
            syncn the SharePoint library created in previous step, ref: https://docs.microsoft.com/en-us/onedrive/use-group-policy#configure-team-site-libraries-to-sync-automatically

.NOTES
    Author: Rajesh Khanikar
    Last edited: 2018-09-20
    Version: 1.0
#>


$ErrorActionPreference = 'Stop'
$exitCode = 0 #To check if the script completed successfully

# Function defines a log file to be created
function AddLog {
    param (

        $Path = "C:\Users\Public\Documents\Apply-BGinfo.log", #This log file can be checked for any issues with the script execution
        $Log
    )
    
    Add-Content $path $log
}

$DateTime = get-date -f "dd-MM-yyyy HH:mm:ss"

AddLog -Log "$DateTime : Starting a new instance of this script."

$TaskName = 'Apply-BGinfo' + $env:USERNAME #If more than one user signs in to the computer, each must have a task because it must run on user logon with %USERPROFILE% path

$Execute = '"%USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\BGinfo64.exe"' #Please see PREREQUISITES for more info

$Argument = '"%USERPROFILE%\[COMPANY]\[SITENAME-DOCUMENTS]\BGinfo\BGinfo.bgi" /timer:0 /silent /NOLICPROMPT"' #Please see PREREQUISITES for more info

$Action = New-ScheduledTaskAction -Execute $Execute -Argument $Argument 

$Trigger =  New-ScheduledTaskTrigger -Atlogon -User $env:USERNAME

$Trigger.Delay = 'PT1M' #Delay is required to allow OneDrive to start and settle down

$TaskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $TaskName } # Check if a task was previously created

Try
{

    if(!$TaskExists) 
    {
        AddLog -Log "$DateTime : Task $TaskName does not exist in the Task Scheduler, will attempt to create the task." #Enter a log entry
        Register-ScheduledTask -TaskName $TaskName -Description $TaskName -Action $Action -Trigger $Trigger -Force #Register the taskk if does not exists
        AddLog -Log "$DateTime : Created the task $TaskName" #Enter a log entry
    } 

    Else
    {
        AddLog -Log "$DateTime : Task $TaskName already exists, will attempt to update the task." #Enter a log entry
        AddLog -Log "$DateTime : Removing the $TaskName..." #Enter a log entry
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$False #Delete if an existing task was found with the same name
        AddLog -Log "$DateTime : Successfully removed the $TaskName..." #Enter a log entry
        AddLog -Log "$DateTime : Adding a new updated task with the same name $TaskName... " #Enter a log entry
        Register-ScheduledTask -TaskName $TaskName -Description $TaskName -Action $Action -Trigger $Trigger -Force #Register the taskk
        AddLog -Log "$DateTime : Successfully added a new task with the same name $TaskName..." #Enter a log entry

    }
   
}

Catch
{
    
    AddLog -Log "$DateTime : Script encountered an error. Error returned was: $($PSItem.ToString())"
    $exitCode = -1 #Scripts exits with an error, helpful to check under Intune admin portal
    
}

Exit $exitCode #Successfully excuted, helpful to check under Intune admin portal
