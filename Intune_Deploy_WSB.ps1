$Current_Folder = split-path $MyInvocation.MyCommand.Path
$xml = "$Current_Folder\Sandbox_Config.xml"
$my_xml = [xml] (Get-Content $xml)
$Sandbox_VGpu = $my_xml.Configuration.VGpu
$Sandbox_Networking = $my_xml.Configuration.Networking
$Sandbox_ReadOnlyAccess = $my_xml.Configuration.ReadOnlyAccess
$Sandbox_Sources_Location = $my_xml.Configuration.Sources_Location
$Sandbox_WSB_Location = $my_xml.Configuration.WSB_Location
$Sandbox_WSB_Name = $my_xml.Configuration.Content_Name
$Sandbox_File_To_Run = $my_xml.Configuration.File_To_Run
$Sandbox_Silent_Switches = $my_xml.Configuration.Silent_Switches

$SystemRoot = $env:SystemRoot
$Log_File = "$SystemRoot\Debug\Deploy_WSB_$Sandbox_WSB_Name.log"
$Container_State = $False
$HyperV_State = $False
$Sandbox_Desktop_Path = "C:\Users\WDAGUtilityAccount\Desktop"
$Appli_To_Run = "$Sandbox_Desktop_Path\$Sandbox_WSB_Name"
$Full_Startup_Path = "$Appli_To_Run\$Sandbox_File_To_Run"

If($Sandbox_File_To_Run -like "*.exe*")
	{
		$Startup_Command = "$Appli_To_Run\$Sandbox_File_To_Run" + " $Sandbox_Silent_Switches"
	}
ElseIf($Sandbox_File_To_Run -like "*.msi*")
	{
		$Startup_Command = "$Full_Startup_Path $Sandbox_Silent_Switches"			
	}
ElseIf($Sandbox_File_To_Run -like "*.ps1*")
	{
		$Startup_Command = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -sta -WindowStyle Hidden -noprofile -executionpolicy unrestricted -file $Full_Startup_Path $Sandbox_Silent_Switches"				
	}	
ElseIf($Sandbox_File_To_Run -like "*.vbs*")
	{
		$Startup_Command = "wscript.exe $Full_Startup_Path $Sandbox_Silent_Switches"	
	}	

If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}
Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"			
	}


Write_Log -Message_Type "INFO" -Message "Starting creation of the Sandbox $Sandbox_WSB_Name"											
Add-content $Log_File ""	

	
Write_Log -Message_Type "INFO" -Message "Checking the current Windows Sandbox status"
  
$Sandbox_Status = $False
$WindowsFeature = "Containers-DisposableClientVM"
Try 
	{
		$WindowsFeatureState = (Get-WindowsOptionalFeature -FeatureName $WindowsFeature -Online).State
		If($WindowsFeatureState -eq "Enabled") 
			{
				$Sandbox_Status = $True
				Write_Log -Message_Type "INFO" -Message "The Sandbox feature is already enabled"    
			} 
		Else
			{
				Write_Log -Message_Type "INFO" -Message "The Sandbox feature is not enabled"         
				$Sandbox_Status = $False  
			Try 
				{
					Write_Log -Message_Type "INFO" -Message "The Sandbox feature is being enabled"    

					Enable-WindowsOptionalFeature -FeatureName $WindowsFeature -Online -NoRestart -ErrorAction Stop
					Write_Log -Message_Type "SUCCESS" -Message "The Sandbox feature has been successfully enabled"          
					$Sandbox_Status = $True    
				}
			catch 
				{
					Write_Log -Message_Type "ERROR" -Message "Failed to enable the Sandbox feature"          
				}
			}   
	}
catch 
	{
		Write_Log -Message_Type "ERROR" -Message "Failed to enable the Sandbox feature"             
	}
  
Add-content $Log_File ""        
If($Sandbox_Status -eq $True)
{ 
	Write_Log -Message_Type "INFO" -Message "Checking if the current user is member of the Hyper-V administrators group"     
	$Get_HyperV_Group = (get-LocalGroup | Where {$_.Name -like "*Hyper-V*"}).name 
	$Get_Current_user = (gwmi win32_computersystem).username
	Write_Log -Message_Type "INFO" -Message "The current user is $Get_Current_user"     	
	$Get_HyperV_Users = get-LocalGroupMember -group $Get_HyperV_Group | where {$_.Name -like "$Get_Current_user"} 
	If($Get_HyperV_Users -eq $null)
		{
			Write_Log -Message_Type "INFO" -Message "The current user is not member of the group Hyper-V administrators"     

			Try
				{
					Add-LocalGroupMember -Group $Get_HyperV_Group -Member "Domain users"     
					Write_Log -Message_Type "SUCCESS" -Message "The group Domain users has been successfully added in the group Hyper-V administrators"          
				}
			Catch
				{
					Write_Log -Message_Type "ERROR" -Message "An issue occured while adding the group Domain users in the group Hyper-V administrators"     
				}
		}
	Else
		{
			Write_Log -Message_Type "INFO" -Message "Current user is already member of the group Hyper-V administrators"     
		}
		
		
		
		
		
} 

Add-content $Log_File ""        
	
Write_Log -Message_Type "INFO" -Message "Checking the Sandbox configuration"     
	
If($Sandbox_WSB_Location -eq "Default")
	{  
		$Get_Current_user_Name = $Get_Current_user.Split("\")[1]
		$User_Profile = "C:\Users\$Get_Current_user_Name"
		# $User_Profile = $env:USERPROFILE
		$User_Desktop = "$User_Profile\Desktop"
		$Sandbox_File_Path = "$User_Desktop\$Sandbox_WSB_Name.wsb"	
		
		Write_Log -Message_Type "INFO" -Message "Sandbox WSB location is configured to: Default"     
		Write_Log -Message_Type "INFO" -Message "The WSB file will be saved in: $Sandbox_File_Path"   		
	}
Else
	{
		$Sandbox_File_Path = "$Sandbox_WSB_Location\$Sandbox_WSB_Name.wsb"	

		Write_Log -Message_Type "INFO" -Message "Sandbox WSB location is configured to: Sandbox_WSB_Location"     
		Write_Log -Message_Type "INFO" -Message "The WSB file will be saved in: $Sandbox_File_Path"  		
	}
	
	
If($Sandbox_Sources_Location -eq "Default")
	{
		# $User_Profile = $env:USERPROFILE
		# $User_Desktop = "$User_Profile\Desktop"
		# $Host_Folder = "$User_Desktop\$Sandbox_WSB_Name"			
		$ProgData = $env:PROGRAMDATA
		$Host_Folder = "$ProgData\$Sandbox_WSB_Name"
		
		Write_Log -Message_Type "INFO" -Message "Sandbox appli location is configured to: Default"     
		Write_Log -Message_Type "INFO" -Message "The WSB file will be saved in: $Host_Folder"  		
	}
Else
	{
		$Host_Folder = "$Sandbox_Sources_Location\$Sandbox_WSB_Name"	
		
		Write_Log -Message_Type "INFO" -Message "Sandbox appli location is configured to: $Sandbox_Sources_Location"     
		Write_Log -Message_Type "INFO" -Message "Application sources will be saved in: $Host_Folder"  		
	}
		
Try
	{
		new-item $Host_Folder -Type Directory -Force | out-null		
		copy-item "$Current_Folder\Sources\*" $Host_Folder
		Write_Log -Message_Type "SUCCESS" -Message "Applications sources have been successfully copied to $Sources_Folder_To_Create"  		
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "Applications sources have not been successfully copied"  		
	}

	
new-item $Sandbox_File_Path -type file -force | out-null
add-content $Sandbox_File_Path  "<Configuration>"	
add-content $Sandbox_File_Path  "<VGpu>$Sandbox_VGpu</VGpu>"	
add-content $Sandbox_File_Path  "<Networking>$Sandbox_Networking</Networking>"	

add-content $Sandbox_File_Path  "<MappedFolders>"	
add-content $Sandbox_File_Path  "<MappedFolder>"	
add-content $Sandbox_File_Path  "<HostFolder>$Host_Folder</HostFolder>"	
add-content $Sandbox_File_Path  "<ReadOnly>$Sandbox_ReadOnlyAccess</ReadOnly>"	
add-content $Sandbox_File_Path  "</MappedFolder>"	
add-content $Sandbox_File_Path  "</MappedFolders>"	

add-content $Sandbox_File_Path  "<LogonCommand>"	
add-content $Sandbox_File_Path  "<Command>$Startup_Command</Command>"	
add-content $Sandbox_File_Path  "</LogonCommand>"	
add-content $Sandbox_File_Path  "</Configuration>"		

Add-content $Log_File ""        
Write_Log -Message_Type "INFO" -Message "Ending creation of the Sandbox $Sandbox_WSB_Name"				

& $Sandbox_File_Path