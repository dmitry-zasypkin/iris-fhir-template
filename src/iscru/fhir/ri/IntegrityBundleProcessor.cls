Class iscru.fhir.ri.IntegrityBundleProcessor Extends HS.FHIRServer.Storage.Json.BundleProcessor
{

/// Method has been copied from HS.FHIRServer.DefaultBundleProcessor (2021.2).
/// The only change applied: reference visitor class name has been replaced with iscru.fhir.ri.EnhancedReferenceVisitor
/// in order not to miss references within contained FHIR resources.
ClassMethod ProcessBundle(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, pResponse As HS.FHIRServer.API.Data.Response)
{
	// Transaction Processing:
	//	1. Map 'fullUrl' -> entry# for each POST entry
	//	2. Visit all references, capture:
	//		References that are "search urls"
	//		References the target one of the 'POST' entry fullUrl values
	//	3. Resolve the search urls to resource references
	//  4. Resolve references for each POST result
	//	5. execute other operations and return result.
	Set tSC = $$$OK
	
	Set startZH = $ZHorolog

	#dim bundle as %DynamicObject = pRequest.Json
	
	if bundle="" {
		$$$ThrowFHIR($$$HSFHIRErrAPIContractViolation, "request.Json")
	}
	
	// Validate the bundle and throw on error
	Do $classmethod(..#BundleValidatorClass, "ValidateBundle", bundle, pService.Schema.FHIRVersion)
	
	// Extract the bundle type
	Set tBundleType = bundle.type
	If (tBundleType="transaction") {
		Set isTransaction = 1
	} elseif (tBundleType="batch") {
		Set isTransaction = 0
	} else {
		$$$ThrowFHIR($$$HSFHIRErrInvalidBundleTypeForTransaction, tBundleType, $$$OutcomeIs(400, "error", "invalid"))
	}


	// Populate the Context object with the entries
	Set visitContext("entry") = 0
	Set iter = bundle.entry.%GetIterator()
	while iter.%GetNext(.subscr, .entryObj) {
		// Append to the Entry List
		Set iEntry = $I(visitContext("entry"))
		Set visitContext("entry", iEntry) = entryObj
		Set reqObj = entryObj.request
		Set rsrcObj = entryObj.resource
		
		// Append to the ByMethod list
		Set methodIndex = $I(visitContext("ByMethod", reqObj.method))
		Set visitContext("ByMethod", reqObj.method, methodIndex) = iEntry

		// If the entry is a POST and has a fullUrl, capture the fullUrl for reference resolution
		// after the entry is created, we will replace the fullUrl value with the actual resource ID
		if isTransaction && (reqObj.method  = "POST") {
			// Grab the UUID if the fullUrl is specified
			Set fullUrl = ..ExtractUUID(entryObj.fullUrl)
			if fullUrl '= "" {
				// Save the reference Key with the entry, so we can resolve during POST
				Set visitContext("entry", iEntry, "fullUrl") = fullUrl
				// This will become the resolved id when the POST is executed
				Set visitContext("ByFullUrl", fullUrl) = iEntry
				// Save which entry the referenceKey refers to
				//Set visitContext("ByFullUrl", fullUrl, "resolve") = ""
				//w "Key for ",iEntry,": ", entryObj.fullUrl," is ",fullUrl,!
			}
		}
	}
	
	// Now for each resource in the bundle, collect the internal references and ensure they are present
	// (meaning there was a fullUrl declaration on a POSTed resource within the bundle)
	
	// Prepare Visit Context for reference walking
	Set visitContext("schema") = pService.Schema
	Set visitContext("callbackClass") = $classname()
	Set visitContext("callbackMethod") = "BuildDependencyCallback"
	
	// Check every reference field in every entry that provides a resource.  If the
	// reference contains an intra-bundle reference, capture the OREF to the Reference object
	// so we can resolve it when the referenced resource is POST'ed.
	set entryId = ""
	for {
		Set entryId = $Order(visitContext("entry", entryId))
		Quit:(entryId="")

		Set entryObj = visitContext("entry", entryId)
		Set visitContext("visiting") = entryId
		if entryObj.resource {
			Do ##class(iscru.fhir.ri.EnhancedReferenceVisitor).VisitAll(entryObj.resource, .visitContext)
		}
	}
	
	// Now build the POST order based on the dependencies .... Error if circular references exist
	set postIndex = ""
	Set postContext("list") = 0
	Set count = 0
	for {
		Set postIndex = $Order(visitContext("ByMethod", "POST", postIndex), 1, entryId)
		Quit:(postIndex="")
		
		Do ..AddToPostOrder(entryId, .visitContext, .postContext)
		Set count = count + 1
	}
	
	// Update the POST requests to follow the order derived based on dependencies
	kill visitContext("ByMethod", "POST")
	Merge visitContext("ByMethod", "POST") = postContext("list")
	kill postContext


	// More to do
	If (tBundleType="transaction") || (tBundleType="batch") {
		Do ..ExecuteBundle(pService, pRequest, pResponse, tBundleType, .visitContext)
	} else {
		$$$ThrowFHIR($$$HSFHIRErrInvalidBundleTypeForTransaction, tBundleType, $$$OutcomeIs(400, "error", "invalid"))
	}
	
	$$$FSLog(tBundleType _ " Bundle ProcessBundle() elapsed = " _ ($ZHorolog-startZH))
}

}

