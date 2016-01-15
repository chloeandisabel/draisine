trigger Create_Deleted_Object on Lead (after delete) {
  List <Lead> leads = Trigger.old;
  for (Lead lead: leads) {
    Deleted_Object__c delObj = new Deleted_Object__c(Object_Id__c = lead.Id, Object_Type__c = 'Salesforce::Lead');
    insert delObj;
  }
}
