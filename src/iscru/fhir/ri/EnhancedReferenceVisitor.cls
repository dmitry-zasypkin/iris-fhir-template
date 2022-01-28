Class iscru.fhir.ri.EnhancedReferenceVisitor Extends HS.FHIRServer.Util.ReferenceVisitor
{

/// Method has been copied from HS.FHIRServer.Util.ReferenceVisitor (2021.2).
/// Two modifications marked with "//dz" comment enable visiting references within contained FHIR resources.
ClassMethod AddReferencesFromObject(pObj As %DynamicObject, pFHIRType As %String, ByRef context) [ Private ]
{
	#dim meta as HS.FHIRMeta.API = context("schema")
	#dim iter as %Iterator.Object = pObj.%GetIterator()
	while iter.%GetNext(.propName, .propValue) {
		Set jsonType = meta.GetPropertyJSONType(pFHIRType, propName)
		Set fhirType = meta.GetPropertyFHIRType(pFHIRType, propName)
		//set ^tl($i(^tl)) = $lb(propName, pFHIRType, jsonType, fhirType, meta.IsPropertyArray(pFHIRType, propName))
		// Handle Canonicals here (eventually)
		Continue:((jsonType '= "o") && (propName '= "contained")) //dz
		
		if meta.IsPropertyArray(pFHIRType, propName) {
			#dim arrayIter as %Iterator.Array = propValue.%GetIterator()
			while arrayIter.%GetNext(.subscr, .arrayEl) {
				if arrayEl '= "" {
					if (fhirType = "Reference") {
						if arrayEl.reference '= "" {
							Do ..AddReferenceObj(arrayEl, .context)
						}
					}
					else {
						//dz
						//Do ..AddReferencesFromObject(arrayEl, fhirType, .context)
						Do ..AddReferencesFromObject(arrayEl, $case(propName, "contained":arrayEl.resourceType, :fhirType), .context)
					}
				}
			}			
		} else {
			if fhirType = "Reference" {
				if propValue.reference '= "" {
					Do ..AddReferenceObj(propValue, .context)
				}
			} elseif fhirType = "canonical" {
				// We don't handle this yet.	
			} elseif meta.GetPropertyJSONType(pFHIRType, propName) = "o" {
				Do ..AddReferencesFromObject(propValue, fhirType, .context)
			}
		}
	}
}

}

