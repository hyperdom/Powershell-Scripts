function Connect-Exchange
{ 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [PSCredential]$Credentials
    )  
 	Begin
		 {
		## Load Managed API dll  
		###CHECK FOR EWS MANAGED API, IF PRESENT IMPORT THE HIGHEST VERSION EWS DLL, ELSE EXIT
		$EWSDLL = (($(Get-ItemProperty -ErrorAction SilentlyContinue -Path Registry::$(Get-ChildItem -ErrorAction SilentlyContinue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Exchange\Web Services'|Sort-Object Name -Descending| Select-Object -First 1 -ExpandProperty Name)).'Install Directory') + "Microsoft.Exchange.WebServices.dll")
		if (Test-Path $EWSDLL)
		    {
		    Import-Module $EWSDLL
		    }
		else
		    {
		    "$(get-date -format yyyyMMddHHmmss):"
		    "This script requires the EWS Managed API 1.2 or later."
		    "Please download and install the current version of the EWS Managed API from"
		    "http://go.microsoft.com/fwlink/?LinkId=255472"
		    ""
		    "Exiting Script."
		    exit
		    } 
  
		## Set Exchange Version  
		$ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010_SP2  
		  
		## Create Exchange Service Object  
		$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)  
		  
		## Set Credentials to use two options are availible Option1 to use explict credentials or Option 2 use the Default (logged On) credentials  
		  
		#Credentials Option 1 using UPN for the windows Account  
		#$psCred = Get-Credential  
		$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString())  
		$service.Credentials = $creds      
		#Credentials Option 2  
		#service.UseDefaultCredentials = $true  
		 #$service.TraceEnabled = $true
		## Choose to ignore any SSL Warning issues caused by Self Signed Certificates  
		  
		## Code From http://poshcode.org/624
		## Create a compilation environment
		$Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
		$Compiler=$Provider.CreateCompiler()
		$Params=New-Object System.CodeDom.Compiler.CompilerParameters
		$Params.GenerateExecutable=$False
		$Params.GenerateInMemory=$True
		$Params.IncludeDebugInformation=$False
		$Params.ReferencedAssemblies.Add("System.DLL") | Out-Null

$TASource=@'
  namespace Local.ToolkitExtensions.Net.CertificatePolicy{
    public class TrustAll : System.Net.ICertificatePolicy {
      public TrustAll() { 
      }
      public bool CheckValidationResult(System.Net.ServicePoint sp,
        System.Security.Cryptography.X509Certificates.X509Certificate cert, 
        System.Net.WebRequest req, int problem) {
        return true;
      }
    }
  }
'@ 
		$TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
		$TAAssembly=$TAResults.CompiledAssembly

		## We now create an instance of the TrustAll and attach it to the ServicePointManager
		$TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
		[System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

		## end code from http://poshcode.org/624
		  
		## Set the URL of the CAS (Client Access Server) to use two options are availbe to use Autodiscover to find the CAS URL or Hardcode the CAS to use  
		  
		#CAS URL Option 1 Autodiscover  
		$service.AutodiscoverUrl($MailboxName,{$true})  
		Write-host ("Using CAS Server : " + $Service.url)   
		   
		#CAS URL Option 2 Hardcoded  
		  
		#$uri=[system.URI] "https://casservername/ews/exchange.asmx"  
		#$service.Url = $uri    
		  
		## Optional section for Exchange Impersonation  
		  
		#$service.ImpersonatedUserId = new-object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $MailboxName) 
		if(!$service.URL){
			throw "Error connecting to EWS"
		}
		else
		{		
			return $service
		}
	}
}
####################### 
<# 
.SYNOPSIS 
 Creates a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
 
.DESCRIPTION 
  Creates a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
  
  Requires the EWS Managed API from https://www.microsoft.com/en-us/download/details.aspx?id=42951

.EXAMPLE
	Example 1 To create a contact in the default contacts folder 
	Create-Contact -Mailboxname mailbox@domain.com -EmailAddress contactEmai@domain.com -FirstName John -LastName Doe -DisplayName "John Doe"
	
	Example 2 To create a contact and add a contact picture
	Create-Contact -Mailboxname mailbox@domain.com -EmailAddress contactEmai@domain.com -FirstName John -LastName Doe -DisplayName "John Doe" -photo 'c:\photo\Jdoe.jpg'

	Example 3 To create a contact in a user created subfolder 
	Create-Contact -Mailboxname mailbox@domain.com -EmailAddress contactEmai@domain.com -FirstName John -LastName Doe -DisplayName "John Doe" -Folder "\MyCustomContacts"
    
	This cmdlet uses the EmailAddress as unique key so it wont let you create a contact with that email address if one already exists.
#> 
########################
function Create-Contact 
{ 
    [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
 		[Parameter(Position=1, Mandatory=$true)] [string]$DisplayName,
		[Parameter(Position=2, Mandatory=$true)] [string]$FirstName,
		[Parameter(Position=3, Mandatory=$true)] [string]$LastName,
		[Parameter(Position=4, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=5, Mandatory=$false)] [string]$CompanyName,
		[Parameter(Position=6, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=7, Mandatory=$false)] [string]$Department,
		[Parameter(Position=8, Mandatory=$false)] [string]$Office,
		[Parameter(Position=9, Mandatory=$false)] [string]$BusinssPhone,
		[Parameter(Position=10, Mandatory=$false)] [string]$MobilePhone,
		[Parameter(Position=11, Mandatory=$false)] [string]$HomePhone,
		[Parameter(Position=12, Mandatory=$false)] [string]$IMAddress,
		[Parameter(Position=13, Mandatory=$false)] [string]$Street,
		[Parameter(Position=14, Mandatory=$false)] [string]$City,
		[Parameter(Position=15, Mandatory=$false)] [string]$State,
		[Parameter(Position=16, Mandatory=$false)] [string]$PostalCode,
		[Parameter(Position=17, Mandatory=$false)] [string]$Country,
		[Parameter(Position=18, Mandatory=$false)] [string]$JobTitle,
		[Parameter(Position=19, Mandatory=$false)] [string]$Notes,
		[Parameter(Position=20, Mandatory=$false)] [string]$Photo,
		[Parameter(Position=21, Mandatory=$false)] [string]$FileAs,
		[Parameter(Position=22, Mandatory=$false)] [string]$WebSite,
		[Parameter(Position=23, Mandatory=$false)] [string]$Title,
		[Parameter(Position=24, Mandatory=$false)] [string]$Folder

		
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($Folder){
			$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
		}
		else{
			$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
		}
		if($service.URL){
			$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
			$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
			$ParentFolderIds = [Activator]::CreateInstance($type)
			$ParentFolderIds.Add($Contacts.Id)
			$Error.Clear();
			$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
			$createContactOkay = $false
			if($Error.Count -eq 0){
				if ($ncCol.Count -eq 0) {
					$createContactOkay = $true;	
				}
				else{
					foreach($Result in $ncCol){
						if($Result.Contact -eq $null){
							Write-host "Contact already exists " + $Result.Mailbox.Name
							throw ("Contact already exists")
						}
						else{
							if((Validate-EmailAddres -EmailAddress $EmailAddress)){
								if($Result.Mailbox.MailboxType -eq [Microsoft.Exchange.WebServices.Data.MailboxType]::Mailbox){
									$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $Result.Mailbox.Address
									$ncCola = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
									if ($ncCola.Count -eq 0) {  
										$createContactOkay = $true;		
									}
									else
									{
										Write-Host -ForegroundColor  Red ("Number of existing Contacts Found " + $ncCola.Count)
										foreach($Result in $ncCola){
											Write-Host -ForegroundColor  Red ($ncCola.Mailbox.Name)
										}
										throw ("Contact already exists")
									}
								}
							}
							else{
								Write-Host -ForegroundColor Yellow ("Email Address is not valid for GAL match")
							}
						}
					}
				}
				if($createContactOkay){
					$Contact = New-Object Microsoft.Exchange.WebServices.Data.Contact -ArgumentList $service 
					#Set the GivenName
					$Contact.GivenName = $FirstName
					#Set the LastName
					$Contact.Surname = $LastName
					#Set Subject  
					$Contact.Subject = $DisplayName
					$Contact.FileAs = $DisplayName
					if($Title -ne ""){
						$PR_DISPLAY_NAME_PREFIX_W = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x3A45,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String);  
						$Contact.SetExtendedProperty($PR_DISPLAY_NAME_PREFIX_W,$Title)						
					}
					$Contact.CompanyName = $CompanyName
					$Contact.DisplayName = $DisplayName
					$Contact.Department = $Department
					$Contact.OfficeLocation = $Office
					$Contact.CompanyName = $CompanyName
					$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessPhone] = $BusinssPhone
					$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::MobilePhone] = $MobilePhone
					$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::HomePhone] = $HomePhone
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business] = New-Object  Microsoft.Exchange.WebServices.Data.PhysicalAddressEntry
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].Street = $Street
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].State = $State
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].City = $City
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].CountryOrRegion = $Country
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].PostalCode = $PostalCode
					$Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1] = $EmailAddress
					$Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1] = $IMAddress 
					$Contact.FileAs = $FileAs
					$Contact.BusinessHomePage = $WebSite
					#Set any Notes  
					$Contact.Body = $Notes
					$Contact.JobTitle = $JobTitle
					if($Photo){
						$fileAttach = $Contact.Attachments.AddFileAttachment($Photo)
						$fileAttach.IsContactPhoto = $true
					}
			   		$Contact.Save($Contacts.Id)				
					Write-Host ("Contact Created")
				}
			}
		}
	}
}
####################### 
<# 
.SYNOPSIS 
 Gets a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
 
.DESCRIPTION 
  Gets a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
  
  Requires the EWS Managed API from https://www.microsoft.com/en-us/download/details.aspx?id=42951

.EXAMPLE
	Example 1 To get a Contact from a Mailbox's default contacts folder
	Get-Contact -MailboxName mailbox@domain.com -EmailAddress contact@email.com
	
	Example 2  The Partial Switch can be used to do partial match searches. Eg to return all the contacts that contain a particular word (note this could be across all the properties that are searched) you can use
	Get-Contact -MailboxName mailbox@domain.com -EmailAddress glen -Partial

	Example 3 By default only the Primary Email of a contact is checked when you using ResolveName if you want it to search the multivalued Proxyaddressses property you need to use something like the following
	Get-Contact -MailboxName  mailbox@domain.com -EmailAddress smtp:info@domain.com -Partial

    Example 4 Or to search via the SIP address you can use
	Get-Contact -MailboxName  mailbox@domain.com -EmailAddress sip:info@domain.com -Partial

#> 
########################
function Get-Contact 
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [string]$Folder,
		[Parameter(Position=4, Mandatory=$false)] [switch]$SearchGal,
		[Parameter(Position=3, Mandatory=$false)] [switch]$Partial
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($SearchGal)
		{
			$Error.Clear();
			$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryOnly,$true);
			if($Error.Count -eq 0){
				foreach($Result in $ncCol){	
					if(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent){
						Write-Output $ncCol.Contact
					}
					else{
						Write-host -ForegroundColor Yellow ("Partial Match found but not returned because Primary Email Address doesn't match consider using -Partial " + $ncCol.Contact.DisplayName + " : Subject-" + $ncCol.Contact.Subject + " : Email-" + $Result.Mailbox.Address)
					}
				}
			}
		}
		else
		{
			if($Folder){
				$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
			}
			else{
				$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
			}
			if($service.URL){
				$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
				$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
				$ParentFolderIds = [Activator]::CreateInstance($type)
				$ParentFolderIds.Add($Contacts.Id)
				$Error.Clear();
				$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
				if($Error.Count -eq 0){
					if ($ncCol.Count -eq 0) {
						Write-Host -ForegroundColor Yellow ("No Contact Found")		
					}
					else{
						$ResultWritten = $false
						foreach($Result in $ncCol){
							if($Result.Contact -eq $null){
								if(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent){
									$Contact = [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$Result.Mailbox.Id)
									Write-Output $Contact  
									$ResultWritten = $true
								}
							}
							else{
							
								if(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent){
									if($Result.Mailbox.MailboxType -eq [Microsoft.Exchange.WebServices.Data.MailboxType]::Mailbox){
										$ResultWritten = $true
										$UserDn = Get-UserDN -EmailAddress $Result.Mailbox.Address -Credentials $Credentials 
										$ncCola = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
										if ($ncCola.Count -eq 0) {  
											#Write-Host -ForegroundColor Yellow ("No Contact Found")			
										}
										else
										{
											$ResultWritten = $true
											Write-Host ("Number of matching Contacts Found " + $ncCola.Count)
											foreach($aResult in $ncCola){
												$Contact = [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$aResult.Mailbox.Id)
												Write-Output $Contact
											}
											
										}
									}
								}
							}
							
						}
						if(!$ResultWritten){
							Write-Host -ForegroundColor Yellow ("No Contract Found")
						}
					}
				}

				
			}
		}
	}
}
####################### 
<# 
.SYNOPSIS 
 Updates a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
 
.DESCRIPTION 
  Updates a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
  
  Requires the EWS Managed API from https://www.microsoft.com/en-us/download/details.aspx?id=42951

.EXAMPLE
	Example1 Update the phone number of an existing contact
	Update-Contact  -Mailboxname mailbox@domain.com -EmailAddress contactEmai@domain.com -MobilePhone 023213421 

 	Example 2 Update the phone number of a contact in a users subfolder
	Update-Contact  -Mailboxname mailbox@domain.com -EmailAddress contactEmai@domain.com -MobilePhone 023213421 -Folder "\MyCustomContacts"
#> 
########################
function Update-Contact
{ 
    [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
 		[Parameter(Position=1, Mandatory=$false)] [string]$DisplayName,
		[Parameter(Position=2, Mandatory=$false)] [string]$FirstName,
		[Parameter(Position=3, Mandatory=$false)] [string]$LastName,
		[Parameter(Position=4, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=5, Mandatory=$false)] [string]$CompanyName,
		[Parameter(Position=6, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=7, Mandatory=$false)] [string]$Department,
		[Parameter(Position=8, Mandatory=$false)] [string]$Office,
		[Parameter(Position=9, Mandatory=$false)] [string]$BusinssPhone,
		[Parameter(Position=10, Mandatory=$false)] [string]$MobilePhone,
		[Parameter(Position=11, Mandatory=$false)] [string]$HomePhone,
		[Parameter(Position=12, Mandatory=$false)] [string]$IMAddress,
		[Parameter(Position=13, Mandatory=$false)] [string]$Street,
		[Parameter(Position=14, Mandatory=$false)] [string]$City,
		[Parameter(Position=15, Mandatory=$false)] [string]$State,
		[Parameter(Position=16, Mandatory=$false)] [string]$PostalCode,
		[Parameter(Position=17, Mandatory=$false)] [string]$Country,
		[Parameter(Position=18, Mandatory=$false)] [string]$JobTitle,
		[Parameter(Position=19, Mandatory=$false)] [string]$Notes,
		[Parameter(Position=20, Mandatory=$false)] [string]$Photo,
		[Parameter(Position=21, Mandatory=$false)] [string]$FileAs,
		[Parameter(Position=22, Mandatory=$false)] [string]$WebSite,
		[Parameter(Position=23, Mandatory=$false)] [string]$Title,
		[Parameter(Position=24, Mandatory=$false)] [string]$Folder,
		[Parameter(Mandatory=$false)] [switch]$Partial,
		[Parameter(Mandatory=$false)] [switch]$force
		
    )  
 	Begin
	{
		if($Partial.IsPresent){$force = $false}
		if($Folder){
			if($Partial.IsPresent){
				$Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials -Folder $Folder -Partial
			}
			else{
				$Contacts = $Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials -Folder $Folder
			}
		}
		else{
			if($Partial.IsPresent){
				$Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials  -Partial
			}
			else{
				$Contacts = $Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials 
			}
		}	

		$Contacts | ForEach-Object{
			$Contact = $_
			if(($Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1].Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent){
				$updateOkay = $false
				if($force){
					$updateOkay = $true
				}
				else
				{
					$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""  
		            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","" 
		            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)  
		            $message = "Do you want to update contact with DisplayName " + $contact.DisplayName + " : Subject-" + $contact.Subject + " : Email-" + $Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1].Address 
		            $result = $Host.UI.PromptForChoice($caption,$message,$choices,1)  
		            if($result -eq 0) {                       
						$updateOkay = $true
		            } 
					else{
						Write-Host ("No Action Taken")
					}				
				}
				if($updateOkay){
					if($FirstName -ne ""){
						$Contact.GivenName = $FirstName
					}
					if($LastName -ne ""){
						$Contact.Surname = $LastName
					}
					if($DisplayName -ne ""){
						$Contact.Subject = $DisplayName
					}
					if($Title -ne ""){
						$PR_DISPLAY_NAME_PREFIX_W = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x3A45,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String);  
						$Contact.SetExtendedProperty($PR_DISPLAY_NAME_PREFIX_W,$Title)						
					}
					if($CompanyName -ne ""){
						$Contact.CompanyName = $CompanyName
					}
					if($DisplayName -ne ""){
						$Contact.DisplayName = $DisplayName
					}
					if($Department -ne ""){
						$Contact.Department = $Department
					}
					if($Office -ne ""){
						$Contact.OfficeLocation = $Office
					}
					if($CompanyName -ne ""){
						$Contact.CompanyName = $CompanyName
					}
					if($BusinssPhone -ne ""){
						$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessPhone] = $BusinssPhone
					}
					if($MobilePhone -ne ""){
						$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::MobilePhone] = $MobilePhone
					}
					if($HomePhone -ne ""){
						$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::HomePhone] = $HomePhone
					}
					if($Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business]  -eq $null){
						$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business] = New-Object  Microsoft.Exchange.WebServices.Data.PhysicalAddressEntry
					}
					if($Street -ne ""){
						$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].Street = $Street
					}
					if($State -ne ""){
						$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].State = $State
					}
					if($City -ne ""){
						$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].City = $City
					}
					if($Country -ne ""){
						$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].CountryOrRegion = $Country
					}
					if($PostalCode -ne ""){
						$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].PostalCode = $PostalCode
					}
					if($EmailAddress -ne ""){
						$Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1] = $EmailAddress
					}
					if($IMAddress -ne ""){
						$Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1] = $IMAddress 
					}
					if($FileAs -ne ""){
						$Contact.FileAs = $FileAs
					}
					if($WebSite -ne ""){
						$Contact.BusinessHomePage = $WebSite
					}
					if($Notes -ne ""){  
						$Contact.Body = $Notes
					}
					if($JobTitle -ne ""){
						$Contact.JobTitle = $JobTitle
					}
					if($Photo){
						$fileAttach = $Contact.Attachments.AddFileAttachment($Photo)
						$fileAttach.IsContactPhoto = $true
					}
					$Contact.Update([Microsoft.Exchange.WebServices.Data.ConflictResolutionMode]::AlwaysOverwrite)
					"Contact updated " + $Contact.Subject
				
				}
			}
		}
	}
}

####################### 
<# 
.SYNOPSIS 
 Deletes a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
 
.DESCRIPTION 
  Deletes a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
  
  Requires the EWS Managed API from https://www.microsoft.com/en-us/download/details.aspx?id=42951

.EXAMPLE 
	Example 1 To delete a contact from the default contacts folder
	Delete-Contact -MailboxName mailbox@domain.com -EmailAddress email@domain.com 

	Example2 To delete a contact from a non user subfolder
	Delete-Contact -MailboxName mailbox@domain.com -EmailAddress email@domain.com -Folder \Contacts\Subfolder
#> 
########################
function Delete-Contact 
{

   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [switch]$force,
		[Parameter(Position=4, Mandatory=$false)] [string]$Folder,
		[Parameter(Position=5, Mandatory=$false)] [switch]$Partial
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($Folder){
			$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
		}
		else{
			$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
		}
		if($service.URL){
			$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
			$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
			$ParentFolderIds = [Activator]::CreateInstance($type)
			$ParentFolderIds.Add($Contacts.Id)
			$Error.Clear();
			$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
			if($Error.Count -eq 0){
				if ($ncCol.Count -eq 0) {
					Write-Host -ForegroundColor Yellow ("No Contact Found")		
				}
				else{
					foreach($Result in $ncCol){
						if($Result.Contact -eq $null){
							$contact = [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$Result.Mailbox.Id) 
							if($force){
								if(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower())){
									$contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete)  
									Write-Host ("Contact Deleted " + $contact.DisplayName + " : Subject-" + $contact.Subject + " : Email-" + $Result.Mailbox.Address)
								}
								else
								{
									Write-Host ("This script won't allow you to force the delete of partial matches")
								}
							}
							else{
								if(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent){
								    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""  
		                            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","" 
		                           
		                            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)  
		                            $message = "Do you want to Delete contact with DisplayName " + $contact.DisplayName + " : Subject-" + $contact.Subject + " : Email-" + $Result.Mailbox.Address
		                            $result = $Host.UI.PromptForChoice($caption,$message,$choices,1)  
		                            if($result -eq 0) {                       
		                                $contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete) 
										Write-Host ("Contact Deleted")
		                            } 
									else{
										Write-Host ("No Action Taken")
									}
								}
								
							}
						}
						else{
							if((Validate-EmailAddres -EmailAddress $Result.Mailbox.Address)){
							    if($Result.Mailbox.MailboxType -eq [Microsoft.Exchange.WebServices.Data.MailboxType]::Mailbox){
									$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $Result.Mailbox.Address
									$ncCola = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
									if ($ncCola.Count -eq 0) {  
										Write-Host -ForegroundColor Yellow ("No Contact Found")			
									}
									else
									{
										Write-Host ("Number of matching Contacts Found " + $ncCola.Count)
										$rtCol = @()
										foreach($aResult in $ncCola){
											if(($aResult.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent){
												$contact = [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$aResult.Mailbox.Id) 
												if($force){
													if($aResult.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()){
														$contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete)  
														Write-Host ("Contact Deleted " + $contact.DisplayName + " : Subject-" + $contact.Subject + " : Email-" + $Result.Mailbox.Address)
													}
													else
													{
														Write-Host ("This script won't allow you to force the delete of partial matches")
													}
												}
												else{
												    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""  
						                            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","" 
						                            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)  
						                            $message = "Do you want to Delete contact with DisplayName " + $contact.DisplayName + " : Subject-" + $contact.Subject + " : Email-" + $Result.Mailbox.Address 
						                            $result = $Host.UI.PromptForChoice($caption,$message,$choices,1)  
						                            if($result -eq 0) {                       
						                                $contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete) 
														Write-Host ("Contact Deleted ")
						                            } 
													else{
														Write-Host ("No Action Taken")
													}
													
												}
											}
											else{
												Write-Host ("Skipping Matching because email address doesn't match address on match " + $aResult.Mailbox.Address.ToLower())
											}
										}								
									}
								}
							}
							else
							{
								Write-Host -ForegroundColor Yellow ("Email Address is not valid for GAL match")
							}
						}
					}
				}
			}	
			
		}
	}
}
function Make-UniqueFileName{
    param(
		[Parameter(Position=0, Mandatory=$true)] [string]$FileName
	)
	Begin
	{
	
	$directoryName = [System.IO.Path]::GetDirectoryName($FileName)
    $FileDisplayName = [System.IO.Path]::GetFileNameWithoutExtension($FileName);
    $FileExtension = [System.IO.Path]::GetExtension($FileName);
    for ($i = 1; ; $i++){
            
            if (![System.IO.File]::Exists($FileName)){
				return($FileName)
			}
			else{
					$FileName = [System.IO.Path]::Combine($directoryName, $FileDisplayName + "(" + $i + ")" + $FileExtension);
			}                
            
			if($i -eq 10000){throw "Out of Range"}
        }
	}
}

function Get-ContactFolder{
	param (
	        [Parameter(Position=0, Mandatory=$true)] [string]$FolderPath,
			[Parameter(Position=1, Mandatory=$true)] [string]$SmptAddress,
			[Parameter(Position=2, Mandatory=$true)] [Microsoft.Exchange.WebServices.Data.ExchangeService]$service
		  )
	process{
		## Find and Bind to Folder based on Path  
		#Define the path to search should be seperated with \  
		#Bind to the MSGFolder Root  
		$folderid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot,$SmptAddress)   
		$tfTargetFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)  
		#Split the Search path into an array  
		$fldArray = $FolderPath.Split("\") 
		 #Loop through the Split Array and do a Search for each level of folder 
		for ($lint = 1; $lint -lt $fldArray.Length; $lint++) { 
	        #Perform search based on the displayname of each folder level 
	        $fvFolderView = new-object Microsoft.Exchange.WebServices.Data.FolderView(1) 
	        $SfSearchFilter = new-object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName,$fldArray[$lint]) 
	        $findFolderResults = $service.FindFolders($tfTargetFolder.Id,$SfSearchFilter,$fvFolderView) 
	        if ($findFolderResults.TotalCount -gt 0){ 
	            foreach($folder in $findFolderResults.Folders){ 
	                $tfTargetFolder = $folder                
	            } 
	        } 
	        else{ 
	            Write-host ("Error Folder Not Found check path and try again")  
	            $tfTargetFolder = $null  
	            break  
	        }     
	    }  
		if($tfTargetFolder -ne $null){
			return [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$tfTargetFolder.Id)
		}
		else{
			throw ("Folder Not found")
		}
	}
}
####################### 
<# 
.SYNOPSIS 
 Exports a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API to a VCF File 
 
.DESCRIPTION 
  Exports a Contact in a Contact folder in a Mailbox using the  Exchange Web Services API 
  
  Requires the EWS Managed API from https://www.microsoft.com/en-us/download/details.aspx?id=42951

.EXAMPLE 

	Example 1 To Export a contact to local file
	Export-Contact -MailboxName mailbox@domain.com -EmailAddress address@domain.com -FileName c:\export\filename.vcf
	If the file already exists it will handle creating a unique filename

	Example 2 To export from a contacts subfolder use
	Export-Contact -MailboxName mailbox@domain.com -EmailAddress address@domain.com -FileName c:\export\filename.vcf -folder \contacts\subfolder

#> 
########################
function Export-Contact 
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$true)] [string]$FileName,
		[Parameter(Position=4, Mandatory=$false)] [string]$Folder,
		[Parameter(Position=5, Mandatory=$false)] [switch]$Partial
    )  
 	Begin
	{
		if($Folder){
			if($Partial.IsPresent){
				$Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials -Folder $Folder -Partial
			}
			else{
				$Contacts = $Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials -Folder $Folder
			}
		}
		else{
			if($Partial.IsPresent){
				$Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials  -Partial
			}
			else{
				$Contacts = $Contacts = Get-Contact -MailboxName $MailboxName -EmailAddress $EmailAddress -Credentials $Credentials 
			}
		}	

		$Contacts | ForEach-Object{
			$Contact = $_
			$psPropset= new-object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)    
		  	$psPropset.Add([Microsoft.Exchange.WebServices.Data.ItemSchema]::MimeContent); 
			$Contact.load($psPropset)
			$FileName = Make-UniqueFileName -FileName $FileName
			[System.IO.File]::WriteAllBytes($FileName,$Contact.MimeContent.Content) 
		    write-host ("Exported " + $FileName)  
		
		}
		

	}
}
####################### 
<# 
.SYNOPSIS 
 Exports a Contact from the Global Address List on an Exchange Server using the  Exchange Web Services API to a VCF File 
 
.DESCRIPTION 
  Exports a Contact from the Global Address List on an Exchange Server using the  Exchange Web Services API to a VCF File 
  
  Requires the EWS Managed API from https://www.microsoft.com/en-us/download/details.aspx?id=42951

.EXAMPLE 

	Example 1 To export a GAL Entry to a vcf file 
	Export-GalContact -MailboxName user@domain.com -EmailAddress email@domain.com -FileName c:\export\export.vcf

	Example 2 To export a GAL Entry to vcf including the users photo
	Export-GalContact -MailboxName user@domain.com -EmailAddress email@domain.com -FileName c:\export\export.vcf -IncludePhoto

#> 
########################
function Export-GALContact 
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [switch]$IncludePhoto,
		[Parameter(Position=4, Mandatory=$true)] [string]$FileName,
		[Parameter(Position=5, Mandatory=$false)] [switch]$Partial
    )  
 	Begin
	{
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$Error.Clear();
		$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryOnly,$true);
		if($Error.Count -eq 0){
			foreach($Result in $ncCol){				
				if(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent){
					$ufilename = Make-UniqueFileName -FileName $FileName
					Set-content -path $ufilename "BEGIN:VCARD" 
					add-content -path $ufilename "VERSION:2.1"
					$givenName = ""
					if($ncCol.Contact.GivenName -ne $null){
						$givenName = $ncCol.Contact.GivenName
					}
					$surname = ""
					if($ncCol.Contact.Surname -ne $null){
						$surname = $ncCol.Contact.Surname
					}
					add-content -path $ufilename ("N:" + $surname + ";" + $givenName)
					add-content -path $ufilename ("FN:" + $ncCol.Contact.DisplayName)
					$Department = "";
					if($ncCol.Contact.Department -ne $null){
						$Department = $ncCol.Contact.Department
					}
				
					$CompanyName = "";
					if($ncCol.Contact.CompanyName -ne $null){
						$CompanyName = $ncCol.Contact.CompanyName
					}
					add-content -path $ufilename ("ORG:" + $CompanyName + ";" + $Department)	
					if($ncCol.Contact.JobTitle -ne $null){
						add-content -path $ufilename ("TITLE:" + $ncCol.Contact.JobTitle)
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::MobilePhone] -ne $null){
						add-content -path $ufilename ("TEL;CELL;VOICE:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::MobilePhone])		
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::HomePhone] -ne $null){
						add-content -path $ufilename ("TEL;HOME;VOICE:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::HomePhone])		
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessPhone] -ne $null){
						add-content -path $ufilename ("TEL;WORK;VOICE:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessPhone])		
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessFax] -ne $null){
						add-content -path $ufilename ("TEL;WORK;FAX:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessFax])
					}
					if($ncCol.Contact.BusinessHomePage -ne $null){
						add-content -path $ufilename ("URL;WORK:" + $ncCol.Contact.BusinessHomePage)
					}
					if($ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business] -ne $null){
						if($ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].CountryOrRegion -ne $null){
							$Country = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].CountryOrRegion.Replace("`n","")
						}
						if($ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].City -ne $null){
							$City = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].City.Replace("`n","")
						}
						if($ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].Street -ne $null){
							$Street = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].Street.Replace("`n","")
						}
						if($ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].State -ne $null){
							$State = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].State.Replace("`n","")
						}
						if($ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].PostalCode -ne $null){
							$PCode = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].PostalCode.Replace("`n","")
						}
						$addr = "ADR;WORK;PREF:;" + $Country + ";" + $Street + ";" + $City + ";" + $State + ";" + $PCode + ";" + $Country
						add-content -path $ufilename $addr
					}
					if($ncCol.Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1] -ne $null){
						add-content -path $ufilename ("X-MS-IMADDRESS:" + $ncCol.Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1])
					}
					add-content -path $ufilename ("EMAIL;PREF;INTERNET:" + $ncCol.Mailbox.Address)
					
					
					if($IncludePhoto){
						$PhotoURL = AutoDiscoverPhotoURL -EmailAddress $MailboxName  -Credentials $Credentials
						$PhotoSize = "HR120x120" 
						$PhotoURL= $PhotoURL + "/GetUserPhoto?email="  + $ncCol.Mailbox.Address + "&size=" + $PhotoSize;
						$wbClient = new-object System.Net.WebClient
						$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
						$wbClient.Credentials = $creds
						$photoBytes = $wbClient.DownloadData($PhotoURL);
						add-content -path $ufilename "PHOTO;ENCODING=BASE64;TYPE=JPEG:"
						$ImageString = [System.Convert]::ToBase64String($photoBytes,[System.Base64FormattingOptions]::InsertLineBreaks)
						add-content -path $ufilename $ImageString
						add-content -path $ufilename "`r`n"	
					}
					add-content -path $ufilename "END:VCARD"	
					Write-Host ("Contact exported to " + $ufilename)			
				}						
			}
		}
	}
}

function AutoDiscoverPhotoURL{
       param (
              $EmailAddress="$( throw 'Email is a mandatory Parameter' )",
              $Credentials="$( throw 'Credentials is a mandatory Parameter' )"
              )
       process{
              $version= [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
              $adService= New-Object Microsoft.Exchange.WebServices.Autodiscover.AutodiscoverService($version);
			  $creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
              $adService.Credentials = $creds
              $adService.EnableScpLookup=$false;
              $adService.RedirectionUrlValidationCallback= {$true}
              $adService.PreAuthenticate=$true;
              $UserSettings= new-object Microsoft.Exchange.WebServices.Autodiscover.UserSettingName[] 1
              $UserSettings[0] = [Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::ExternalPhotosUrl
              $adResponse=$adService.GetUserSettings($EmailAddress, $UserSettings)
              $PhotoURI= $adResponse.Settings[[Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::ExternalPhotosUrl]
              return $PhotoURI.ToString()
       }
}
Function Validate-EmailAddres
{
	 param( 
	 	[Parameter(Position=0, Mandatory=$true)] [string]$EmailAddress
	 )
	 Begin
	{
 		try
		{
  			$check = New-Object System.Net.Mail.MailAddress($EmailAddress)
 			 return $true
 		}
 		catch
 		{
  			return $false
 		}
   }
}
####################### 
<# 
.SYNOPSIS 
 Copies a Contact from the Global Address List to a Local Mailbox Contacts folder using the  Exchange Web Services API  
 
.DESCRIPTION 
  Copies a Contact from the Global Address List to a Local Mailbox Contacts folder using the  Exchange Web Services API
  
  Requires the EWS Managed API from https://www.microsoft.com/en-us/download/details.aspx?id=42951

.EXAMPLE 

	Example 1 To Copy a Gal contacts to local Contacts folder
	Copy-Contacts.GalToMailbox -MailboxName mailbox@domain.com -EmailAddress email@domain.com  

 	Example 2 Copy a GAL contact to a Contacts subfolder
	Copy-Contacts.GalToMailbox -MailboxName mailbox@domain.com -EmailAddress email@domain.com  -Folder \Contacts\UnderContacts

#> 
########################
function Copy-Contacts.GalToMailbox
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [string]$Folder,
		[Parameter(Position=4, Mandatory=$false)] [switch]$IncludePhoto
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($Folder){
			$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
		}
		else{
			$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
		}
		$Error.Clear();
		$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryOnly,$true);
		if($Error.Count -eq 0){
			foreach($Result in $ncCol){				
				if($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()){					
					$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
					$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
					$ParentFolderIds = [Activator]::CreateInstance($type)
					$ParentFolderIds.Add($Contacts.Id)
					$Error.Clear();
					$ncCola = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
					$createContactOkay = $false
					if($Error.Count -eq 0){
						if ($ncCola.Count -eq 0) {							
						    $createContactOkay = $true;	
						}
						else{
							foreach($aResult in $ncCola){
								if($aResult.Contact -eq $null){
									Write-host "Contact already exists " + $aResult.Contact.DisplayName
									throw ("Contact already exists")
								}
								else{
									if((Validate-EmailAddres -EmailAddress $Result.Mailbox.Address)){
									    if($Result.Mailbox.MailboxType -eq [Microsoft.Exchange.WebServices.Data.MailboxType]::Mailbox){
											$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $Result.Mailbox.Address
											$ncColb = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
											if ($ncColb.Count -eq 0) {  
												$createContactOkay = $true;		
											}
											else
											{
												Write-Host -ForegroundColor  Red ("Number of existing Contacts Found " + $ncColb.Count)
												foreach($Result in $ncColb){
													Write-Host -ForegroundColor  Red ($ncColb.Mailbox.Name)
												}
												throw ("Contact already exists")
											}
										}
									}
									else{
										Write-Host -ForegroundColor Yellow ("Email Address is not valid for GAL match")
									}
								}
							}
						}
						if($createContactOkay){
							#check for SipAddress
							$IMAddress = ""
							if($ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1] -ne $null){
								$email1 = $ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1].Address
								if($email1.tolower().contains("sip:")){
									$IMAddress = $email1
								}
							}
							if($ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2] -ne $null){
								$email2 = $ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2].Address
								if($email2.tolower().contains("sip:")){
									$IMAddress = $email2
									$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2] = $null
								}
							}
							if($ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3] -ne $null){
								$email3 = $ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3].Address
								if($email3.tolower().contains("sip:")){
									$IMAddress = $email3
									$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3] = $null
								}
							}
							if($IMAddress -ne ""){
								$ncCol.Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1] = $IMAddress
							}	
    						$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2] = $null
							$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3] = $null
							$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1].Address = $ncCol.Mailbox.Address.ToLower()
							$ncCol.Contact.FileAs = $ncCol.Contact.DisplayName
							if($IncludePhoto){					
								$PhotoURL = AutoDiscoverPhotoURL -EmailAddress $MailboxName  -Credentials $Credentials
								$PhotoSize = "HR120x120" 
								$PhotoURL= $PhotoURL + "/GetUserPhoto?email="  + $ncCol.Mailbox.Address + "&size=" + $PhotoSize;
								$wbClient = new-object System.Net.WebClient
								$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
								$wbClient.Credentials = $creds
								$photoBytes = $wbClient.DownloadData($PhotoURL);
								$fileAttach = $ncCol.Contact.Attachments.AddFileAttachment("contactphoto.jpg",$photoBytes)
								$fileAttach.IsContactPhoto = $true
							}
							$ncCol.Contact.Save($Contacts.Id);
							Write-Host ("Contact copied")
						}
					}
				}
			}
		}
	}
}

function Get-UserDN{
	param (
			[Parameter(Position=0, Mandatory=$true)] [string]$EmailAddress,
			[Parameter(Position=1, Mandatory=$true)] [PSCredential]$Credentials
		  )
	process{
		$ExchangeVersion= [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
		$adService = New-Object Microsoft.Exchange.WebServices.AutoDiscover.AutodiscoverService($ExchangeVersion);
		$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
		$adService.Credentials = $creds
		$adService.EnableScpLookup = $false;
		$adService.RedirectionUrlValidationCallback = {$true}
		$UserSettings = new-object Microsoft.Exchange.WebServices.Autodiscover.UserSettingName[] 1
		$UserSettings[0] = [Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::UserDN
		$adResponse = $adService.GetUserSettings($EmailAddress , $UserSettings);
		return $adResponse.Settings[[Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::UserDN]
	}
}