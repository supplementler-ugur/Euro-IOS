//
//  EMSelectorHelpers.m
//  Euro-IOS
//
//  Created by Egemen on 8.05.2020.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "EMSelectorHelpers.h"

BOOL checkIfInstanceOverridesSelector(Class instance, SEL selector) {
    Class instSuperClass = [instance superclass];
    return [instance instanceMethodForSelector: selector] != [instSuperClass instanceMethodForSelector: selector];
}


Class getClassWithProtocolInHierarchy(Class searchClass, Protocol* protocolToFind) {
    if (!class_conformsToProtocol(searchClass, protocolToFind)) {
        if ([searchClass superclass] == nil)
            return nil;
        Class foundClass = getClassWithProtocolInHierarchy([searchClass superclass], protocolToFind);
        if (foundClass)
            return foundClass;
        return searchClass;
    }
    return searchClass;
}

BOOL injectSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getInstanceMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    // Keep - class_getInstanceMethod for existing detection.
    //    class_addMethod will successfuly add if the addToClass was loaded twice into the runtime.
    BOOL existing = class_getInstanceMethod(addToClass, makeLikeSel) != NULL;
    
    if (existing) {
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        newMeth = class_getInstanceMethod(addToClass, newSel);
        Method orgMeth = class_getInstanceMethod(addToClass, makeLikeSel);
        method_exchangeImplementations(orgMeth, newMeth);
    }
    else
        class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    
    return existing;
}

// Try to find out which class to inject to
void injectToProperClass(SEL newSel, SEL makeLikeSel, NSArray* delegateSubclasses, Class myClass, Class delegateClass) {
    
    // Find out if we should inject in delegateClass or one of its subclasses.
    // CANNOT use the respondsToSelector method as it returns TRUE to both implementing and inheriting a method
    // We need to make sure the class actually implements the method (overrides) and not inherits it to properly perform the call
    // Start with subclasses then the delegateClass
    
    for(Class subclass in delegateSubclasses) {
        if (checkIfInstanceOverridesSelector(subclass, makeLikeSel)) {
            injectSelector(myClass, newSel, subclass, makeLikeSel);
            return;
        }
    }
    
    // No subclass overrides the method, try to inject in delegate class
    injectSelector(myClass, newSel, delegateClass, makeLikeSel);
    
}

NSArray* ClassGetSubclasses(Class parentClass) {
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class*)malloc(sizeof(Class) * numClasses);
    
    objc_getClassList(classes, numClasses);
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (NSInteger i = 0; i < numClasses; i++) {
        Class superClass = classes[i];
        
        while(superClass && superClass != parentClass) {
            superClass = class_getSuperclass(superClass);
        }
        
        if (superClass)
            [result addObject:classes[i]];
    }
    
    free(classes);
    
    return result;
}

