@isTest(seeAllData=false)

private class CreateDeletedObjectAfterLeadDeleteTest {
  static testMethod void testCreatedDeletedObject() {
    Test.startTest();
    Lead lead = new Lead(FirstName = 'John', LastName = 'Snow');
    insert lead;
    System.assertEquals([SELECT COUNT() FROM Deleted_Object__c], 0);
    String id = lead.Id;
    delete lead;
    System.assertEquals([SELECT COUNT() FROM Deleted_Object__c], 1);
    System.assertEquals([SELECT Object_Id__c FROM Deleted_Object__c LIMIT 1].Object_Id__c, id);
    Test.stopTest();
  }
}
