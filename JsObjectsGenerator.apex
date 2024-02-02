    public static string buildJavascriptClassDefinitions(list<string> classNames){

        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();

        set<string> validObjects = new set<string>();

        string classDef = '';
        for(string className : classNames){
            try{
                list<string> classNamePathParts = className.split('\\.');
                string exportName = classNamePathParts[classNamePathParts.size()-1];

                //handle sObject definitions
                if(schemaMap.containsKey(className)){
                    classDef += getSojbectDefinition(className);
                }
                //handle custom wrapper class definitions
                else{
                    classDef += buildJavascriptClassDefinition(className);
                }
                validObjects.add(exportName);
            }catch(exception ex){
                classDef += '\r\n\r\n //Unable to define ' + className + ': ' + ex.getMessage() + '\r\n\r\n';
            }
        }

        //add in the constructors
        
        string exportLine = '//export { ' + String.join(new list<string>(validObjects), ', ') + ' } from \'./objects\' //Use this line to export objects from shared component so other components can import them \r\n\r\n';
        string importLine = '//import {  ' + String.join(new list<string>(validObjects), ', ') + '  } from \'c/Your_Object_File_Name_Here\'; //Use this line to import objects into your component \r\n\r\n';
        for(string className : classNames){
            list<string> classNamePathParts = className.split('\\.');
            string definitionName = classNamePathParts[classNamePathParts.size()-1];

            classDef += definitionName+'.prototype.construct = function(constructorData,includeNulls) { for (var k in genericConstruct(constructorData, this, includeNulls)) if (constructorData[k] != undefined) this[k] = constructorData[k]}\r\n';
        }
        classDef = exportLine + importLine + classDef;

        classDef +='\r\n'+ 
            'function genericConstruct(constructorData,objectData,includeNulls=true){\r\n'+
                '\tlet returnObject = {};\r\n'+
                '\tif (typeof constructorData === \'string\') constructorData = JSON.parse(JSON.stringify(constructorData));\r\n'+
                '\tif(typeof constructorData === \'object\') for (let k in objectData) { if (constructorData[k] != undefined) { returnObject[k] = constructorData[k];}}\r\n'+
                '\tif(!includeNulls) for (let k in returnObject) { if (returnObject[k] == null) { delete returnObject[k];}} \r\n'+
                '\treturn returnObject;\r\n'+
            '}\r\n';

		system.debug('\n\n\n\n\n\n--------------------------------------- CLASS DEFINITIONS BELOW-----------------------------------------------------');
        system.debug(classDef);
		system.debug('\n\n\n\n\n\n--------------------------------------- END CLASS DEFINITIONS-----------------------------------------------------');
        return classDef;
    }
    public static string getSojbectDefinition(string objectName){
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String, Schema.SObjectField> fieldMap = schemaMap.get(objectName).getDescribe().fields.getMap();

        string classDef = 'export class ' + objectName + '{\r\n';
        classDef += '\tconstructor(constructorData) { \r\n';
        classDef += '\t\t//Definition Automatically Constructed From Evaluation of ' + objectName + ' sObject\r\n';

        for(String fieldName : fieldMap.keyset() ){

            Schema.DescribeFieldResult thisFieldData = fieldMap.geT(fieldName).getDescribe();
            classDef += '\t\t//Apex Data Type: '+thisFieldData.getType() + '\r\n';
            classDef += '\t\tthis.'+fieldName+ ' = ' + thisFieldData.getDefaultValue() +';\r\n';
        }

        classDef += '\t\tthis.construct(constructorData,includeNulls);\r\n\t}\r\n}\r\n\r\n';

        return classDef;
    }

    public static string buildJavascriptClassDefinition(string className){
        map<string,object> placeholderValues = new map<string,object>();

        Type classType = Type.forName(className);

        Object thisObject = classType.newInstance();

        System.debug(thisObject);

        System.debug(JSON.serializePretty(thisObject));

        map<string,object> objectPropertiesToDefaultsMap = (map<string,object>) JSON.deserializeUntyped(JSON.serialize(thisObject));

        map<string,string> propertyNameToTypeMap = new map<string,string>();

        /*
        for(string propertyName : objectPropertiesToDefaultsMap.keySet()){
            propertyNameToTypeMap.put(propertyName,getTypeX(objectPropertiesToDefaultsMap.get(propertyName)));

            //Type t = Type.forName('AttendanceUtilities.RosterWrapper.'+propertyName);
            //system.debug(propertyName + ': ' + t);
        }*/

        propertyNameToTypeMap = getObjectPropertyTypes(className);

        system.debug('\n\n\n---- Property Name To Type Map');
        system.debug(propertyNameToTypeMap);

        list<string> classNamePathParts = className.split('\\.');

        string classDef = 'export class ' + classNamePathParts[classNamePathParts.size()-1] + '{\r\n';
        classDef += '\tconstructor(constructorData) { \r\n';
        classDef += '\t\t//Definition Automatically Constructed From Evaluation of ' + className + ' Apex Class \r\n';

        list<string> quotedTypes = new list<string>{'Id', 'String', 'Blob'};

        for(string propertyName : objectPropertiesToDefaultsMap.keySet()){
            object defaultVal = objectPropertiesToDefaultsMap.get(propertyName);
            string propertyType = propertyNameToTypeMap.get(propertyName);

            
            if(propertyType.toLowerCase() == 'list') defaultVal = '[]';
            else if(propertyType.toLowerCase() == 'object') defaultVal = '{}}';
            else if(propertyType.toLowerCase() == 'map<string,any>') defaultVal = '{}';
            else if(propertyType.toLowerCase() == 'sobject') defaultVal = '{}';
            else if(quotedTypes.contains(propertyType)) defaultVal = '""';
            

            classDef += '\t\t//Apex Data Type: '+propertyType + '\r\n';
            classDef += '\t\tthis.'+propertyName+ ' = ' + defaultVal +';\r\n';
        }

        classDef += '\t\tthis.construct(constructorData,true);\r\n\t}\r\n}\r\n\r\n';

        system.debug(classDef);

        return classDef;
    
    }
    public static map<string,string> getObjectPropertyTypes(String className){
        map<string,string> propertyTypeNameMap = new map<string,string>();

        Type classType = Type.forName(className);
        Object thisObject = classType.newInstance();
        map<string,object> objectProps = (map<string,object>) JSON.deserializeUntyped(JSON.serialize(thisObject));

        string frontPadding = '{F}';
        string backPadding = '{B}';
        list<string> dataTypes = new list<string>{'sObject','Id','Blob','Time','DateTime','Date','Integer','Long','Decimal','Double','String','Boolean'};

        map<string,object> sampleValuesMap = new map<string,object>();
        sampleValuesMap.put('sObject',new User()); //weirdly enough you can use any sObject as a stand in for another. I guess they all extend the base class or something
        sampleValuesMap.put('Boolean',true);
        sampleValuesMap.put('Id',[SELECT ID FROM USER LIMIT 1][0].Id);
        sampleValuesMap.put('String','Test String');
        sampleValuesMap.put('Blob',Blob.valueof('TestString'));
        sampleValuesMap.put('Date','2010-05-05');
        sampleValuesMap.put('DateTime',DateTime.Now());
        sampleValuesMap.put('Time',Time.newInstance(18, 30, 2, 20));
        sampleValuesMap.put('Integer',500);
        sampleValuesMap.put('Long',2147483648L);
        sampleValuesMap.put('Decimal',10.41231);
        sampleValuesMap.put('Double',2.7182818284D);
   

        
        //one at a time, try to figure out the data type by setting a different value of value
        for(string propName : objectProps.keySet()){
            integer attemptCounter = 0;
            map<string,object> testObject = new map<string,object>();

            for(string dataType : dataTypes){
                
                //if(attemptCounter==0) testObject.put(propName, frontPadding+propName+backPadding);
                testObject.put(propName,sampleValuesMap.get(dataType));

                system.debug('\n--- Setting ' + propName + ' as type ' + dataType + ' with value ' + testObject.get(propName));
                //system.debug(testObject);
            
                try{
                    system.debug(JSON.deserialize(JSON.serialize(testObject),classType));
                    propertyTypeNameMap.put(propName,dataType);
                    system.debug('\n\n\n---Success! Set ' + propName + ' as ' + dataType + ' with value ' + propertyTypeNameMap.get(propName));
                    break;
                }catch(exception e){
                    //extract the error text, remove the bad key, and try again.
                    //17:20:52:000 USER_DEBUG --------------------Expected List<AttendanceUtilities.AttendeeWrapper> but found "attendees.0" at [line:1, column:2]
                    system.debug('\n\n\n\n--------------------'+e.getMessage());
                    string errorString = e.getMessage();
                    string extractedDataType = '';
            
                    if(errorString.startsWith('bad ')){
                        extractedDataType = errorString.substringAfter('bad ').substringBefore((string) testObject.get(propName));		
                    }
                    else if(errorString.startsWith('Expected')){
                        extractedDataType = errorString.substringAfter('Expected ').substringBefore(' but found ');
                    }
                    if(String.isEmpty(extractedDataType)) continue;
            
                    propertyTypeNameMap.put(propName,extractedDataType);
                    system.debug('\n---Success! Set ' + propName + ' as ' + extractedDataType + ' with value ' + propertyTypeNameMap.get(propName));
                    break;
                }
                attemptCounter++;
            }
        }

        return propertyTypeNameMap;
    }
