Class HS.Local.Util.FoundationInstaller Extends HS.Util.Installer.Foundation
{

/// Overridden in order to set up a separate database for program code.
/// Name of the code database is expected in pVars("CodeDBName"). If not specified then we do not set up a separate db for code.
/// 
/// Method has been copied from HS.Util.Installer.ConfigItem (2021.2).
/// Modifications are marked with "//dz" comment.
ClassMethod BuildDBNS(pNamespace, ByRef pVars, ByRef pLogFile, pDoMirror As %Boolean = 1) As %Status
{
	try {
		#dim codeDBName As %String = $get(pVars("CodeDBName"))  //dz
		
		new $namespace
		Set tSC = $$$OK
		Set $namespace="%SYS"
	 	// Check if pNamespace already exists
		Set tExists=##Class(Config.Namespaces).Exists(pNamespace)
		Set $namespace="HSLIB"
		Quit:tExists
		Set tDBName = $TR(pNamespace,"%-_","pdu")
		set DBResource="%DB_"_$ZCVT(tDBName,"U")

		If $Data(pVars("DBInstallDirectory"),tValue)#2 && (tValue '= "") {
			Set tDataDir = ##class(%File).NormalizeDirectory(tValue)
		}

		// Create the IRIS.DAT (if not already there)
		If $G(pVars("FromEnableEnsemble"))'=1 {
			//This gets set by %ZHSLIB.HealthShareMgr - the DB already exists, and might be mixed case
			do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","About to Create Database "_tDBName)
			If $system.Mirror.IsMember() do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","Database Create must wait for all mirror members")
			Set tSC=##class(HS.Util.SystemAPI).CreateDatabase(tDBName, pDoMirror, .tDataDir) Quit:$$$ISERR(tSC)
			do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","Create "_$$$DatabaseFilename_" in "_tDataDir_tDBName)
			
			//dz
			if (codeDBName '= "")
			{
				do ##class(HS.HC.Util.Installer).Log(.pLogFile, $classname(), "Install", "About to Create Database " _ codeDBName)
				If $system.Mirror.IsMember() do ##class(HS.HC.Util.Installer).Log(.pLogFile, $classname(), "Install", "Database Create must wait for all mirror members")
				Set tSC=##class(HS.Util.SystemAPI).CreateDatabase(codeDBName, pDoMirror, .tDataDir) Quit:$$$ISERR(tSC)
				do ##class(HS.HC.Util.Installer).Log(.pLogFile, $classname(), "Install", "Create "_$$$DatabaseFilename_" in "_tDataDir_codeDBName)
			}
		}

		// Create the Namespace (if not already there)
		//dz
		//Set tSC=##class(HS.Util.SystemAPI).Invoke("CreateNamespace",tDBName,pNamespace,tDBName,tDBName) Quit:$$$ISERR(tSC)
		Set tSC=##class(HS.Util.SystemAPI).Invoke("CreateNamespace",tDBName,pNamespace,$case(codeDBName, "":tDBName, :codeDBName),tDBName) Quit:$$$ISERR(tSC)
		
		do ##class(HS.HC.Util.Installer).Log(.pLogFile,$classname(),"Install","Made Namespace "_pNamespace)
	} catch ex {
		Set tSC = ex.AsStatus()
	} 
	Quit tSC
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}

