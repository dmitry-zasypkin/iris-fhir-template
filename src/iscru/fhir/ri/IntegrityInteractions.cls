Class iscru.fhir.ri.IntegrityInteractions Extends HS.FHIRServer.Storage.Json.Interactions
{

Parameter refsGlobal = "^iscru.fhir.ReferentialIntegrityData";

Parameter FHIR400STATUS = {$$$ERROR("<HSFHIRErr>ValidationFailure", "|400|error|invalid")};

Method AddVersion(pCurrentStorageObj As HS.FHIRServer.Storage.Json.Resource, pChangeVerb As %String, pNewResource As %DynamicObject) As HS.FHIRServer.Storage.Json.Resource [ Internal ]
{
	if (pChangeVerb = "DELETE")
	{
		// check if there are any references to the resource being deleted
		#dim refKey As %String = $order(@..#refsGlobal@("to", pCurrentStorageObj.Key, ""))
		if (refKey '= "")
		{
			$$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, refKey _" has a reference to the resource being deleted")))
		}
	}
	else
	{
		// collect all the references found within the inserted/updated resource
		kill visitContext
		set visitContext("schema") = ..strategy.schema
		set visitContext("callbackClass") = $classname()
		set visitContext("callbackMethod") = "collectReferencesCallback"

		do ##class(HS.FHIRServer.Util.ReferenceVisitor).VisitAll(pNewResource, .visitContext)
		
		// check collected references
		#dim ref As %String = ""
		for
		{
			set ref = $order(visitContext("references", ref))
			if (ref = "") quit
			
			//if ($length(ref, "/") '= 2) $$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "Invalid reference: " _ ref)))
			
			#dim rsrcClass As %String = ..strategy.GetResourceClass($piece(ref, "/", 1))   // method argument is ignored (on 2021.2) - see GetResourceClassName() in HS.FHIRServer.Storage.Json.RepoManager class
			
			if (rsrcClass = "") 
						||
					'$classmethod(rsrcClass, "KeyIdxExists", ref) 
						||
					($classmethod(rsrcClass, "DeletedGetStored", $piece(ref, "/", 2)) = "1")
			{
				$$$FSLog("!!!!!!" _ $classmethod(rsrcClass, "DeletedGetStored", $piece(ref, "/", 2)))
				$$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "Referenced resource not found: " _ ref)))
			}
		}
	} // else if (pChangeVerb = "DELETE")

	#dim result As HS.FHIRServer.Storage.Json.Resource = ""
		
	TSTART
	try
	{
		// in case of update or delete: remove existing nodes from ^iscru.fhir.ReferentialIntegrityData
		if $isObject(pCurrentStorageObj)
		{
			#dim key As %String = ""
			for
			{
				set key = $order(@..#refsGlobal@("from", pCurrentStorageObj.Key, key))
				if (key = "") quit
				
				kill @..#refsGlobal@("to", key, pCurrentStorageObj.Key)
			}
			kill @..#refsGlobal@("from", pCurrentStorageObj.Key)
		}
		
		set result = ##super(pCurrentStorageObj, pChangeVerb, pNewResource)
		
		if (pChangeVerb '= "DELETE")
		{
			// add new nodes to ^iscru.fhir.ReferentialIntegrityData
			set ref = ""
			for
			{
				set ref = $order(visitContext("references", ref))
				if (ref = "") quit
				
				set @..#refsGlobal@("from", result.Key, ref) = 1
				set @..#refsGlobal@("to", ref, result.Key) = 1
			}
		}

		TCOMMIT
	}
	catch ex 
	{
		TROLLBACK 1
		throw ex
	}
	
	quit result
}

ClassMethod collectReferencesCallback(ByRef visitContext, refObj As %DynamicObject)
{
	if 'refObj.%IsDefined("reference") quit
	
	// skip references to contained resources
	if ($extract(refObj.reference, 1) = "#") quit
	
	// update references sub-array of visitContext
	set visitContext("references", refObj.reference) = 1
}

}

