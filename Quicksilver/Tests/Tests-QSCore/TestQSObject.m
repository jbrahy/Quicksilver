//
//  TestQSObject.m
//  Quicksilver
//
//  Created by Rob McBroom on 2013/03/01.
//
//

#import "QSTypes.h"
#import "QSDefines.h"
#import "QSObject.h"
#import "QSObject_StringHandling.h"
#import "QSObject_FileHandling.h"
#import "QSObject_URLHandling.h"
#import "QSObject_PropertyList.h"

#import <XCTest/XCTest.h>

@interface TestQSObject : XCTestCase

@end


@implementation TestQSObject

- (void)testStringObject
{
    NSString *exampleString = @"Example string in Quicksilver";
    QSObject *object = [QSObject objectWithString:exampleString];
    XCTAssertEqualObjects([object stringValue], exampleString, @"stringValue mismatch");
    XCTAssertEqualObjects([object objectForType:QSTextType], exampleString, @"QSTextType mismatch");
}

- (void)testURLObject
{
    NSArray *exampleURLs = @[@"qsapp.com", @"http://www.qsapp.com/"];
    for (NSString *url in exampleURLs) {
        QSObject *object = [QSObject URLObjectWithURL:url title:nil];
        XCTAssertTrue([object containsType:QSURLType] && [[object primaryType] isEqualToString:QSURLType], @"URL '%@' was not set up properly", url);
    }
    NSString *searchURL = [NSString stringWithFormat:@"http://www.qsapp.com/?q=%@&other_param=foo", QUERY_KEY];
    QSObject *object = [QSObject URLObjectWithURL:searchURL title:@"Web Search"];
    XCTAssertTrue([object containsType:QSSearchURLType] && [[object primaryType] isEqualToString:QSSearchURLType], @"URL '%@' was not recognized as a web search", searchURL);
}

- (void)testStringSniffing
{
    NSArray *shouldBeURL = @[
        @"localhost",
        @"localhost:1024",
        @"qsapp.com",
        @"http://qsapp.com/",
        @"http://hostname",
        @"http://qsapp.com:8080/path/",
        @"http://hostname.local/",
        @"qsapp/",
        @"qs-app/"
    ];
    for (NSString *url in shouldBeURL) {
        QSObject *object = [QSObject objectWithString:url];
        XCTAssertTrue([object containsType:QSURLType] && [[object primaryType] isEqualToString:QSURLType], @"'%@' was not recognized as a URL", url);
    }
    
    NSArray *shouldBeSearchURL = @[
        @"http://maps.google.com/maps?q=***",
        @"http://google.com:80/?searching=***",
        @"http://en.wikipedia.org/wiki/Special:Search?search=***",
        @"http://en.wikipedia.org:80/wiki/Special:Search?search=***",
        @"http://images.google.com/images?btnG=Search+Images&q=***"
    ];
    for (NSString *url in shouldBeSearchURL) {
        QSObject *object = [QSObject objectWithString:url];
        XCTAssertTrue([object containsType:QSSearchURLType] && [[object primaryType] isEqualToString:QSSearchURLType], @"'%@' was not recognized as a Search URL", url);
    }
    
    NSArray *shouldNotBeURL = @[
        @"com",
        @".com",
        @"ordinary text",
        @"localhost:",
        @"http://localhost:",
        @"host.invalid.topleveldomain",
        @"http://host.invalid.topleveldomain",
        @".co.uk",
        @"abcdefg\nhttp://qsapp.com/",
        @"http://qsapp.com:string:123",
        @"http://qsapp.com:2:colons",
        @"/qsapp/",
        @"qsapp//",
        @"qs.app/",
        @"qs.app/",
        @"qsapp-/",
        @"qsapp:80/"
    ];
    for (NSString *text in shouldNotBeURL) {
        QSObject *object = [QSObject objectWithString:text];
        XCTAssertTrue([[object primaryType] isEqualToString:QSTextType], @"'%@' was not recognized as plain text", text);
    }
    
    NSArray *shouldBeEmail = @[@"mailto:example@fake.tld", @"example@fake.tld"];
    for (NSString *mailto in shouldBeEmail) {
        QSObject *email = [QSObject objectWithString:mailto];
        XCTAssertTrue([[email primaryType] isEqualToString:QSEmailAddressType], @"'%@' was not recongnized as an e-mail address", mailto);
    }
    NSArray *shouldNotBeEmail = @[@"mailto:invalid address", @"example@fake.", @"invalid email@validdomain.com", @"mailto:@domain.com", @"mailto:helpme@.com"];
    for (NSString *mailto in shouldNotBeEmail) {
        QSObject *email = [QSObject objectWithString:mailto];
        XCTAssertTrue([[email primaryType] isEqualToString:QSTextType], @"'%@' should not be treated as an e-mail address", mailto);
    }
    
    NSString *calculation = @"=5*5";
    QSObject *object = [QSObject objectWithString:calculation];
    XCTAssertTrue([[object primaryType] isEqualToString:QSFormulaType], @"'%@' was not recognized as a caculation", calculation);
}

- (void)testObjectType
{
    NSDictionary *objectsAndTypes = @{
        @"QSUnitTestStringType": @"string",
        @"QSUnitTestDictionaryType": @{@"key": @"value"},
        @"QSUnitTestArraySingleValueType" : @[@"alone"],
        @"QSUnitTestArrayType": @[@"one", @"two", @"three"],
        @"QSUnitTestExoticType": [NSImage imageNamed:NSImageNameUser],
        @"QSUnitTestEmptyArrayType" : @[]
    };
    QSObject *object = [QSObject makeObjectWithIdentifier:@"QSUnitTest:objectType"];
    for (NSString *type in [objectsAndTypes allKeys]) {
        id originalObject = [objectsAndTypes objectForKey:type];
        [object setObject:originalObject forType:type];
        id storedObject = [object objectForType:type];
        if ([originalObject isKindOfClass:[NSArray class]]) {
            if ([(NSArray *)originalObject count] == 1) {
                XCTAssertEqualObjects([originalObject lastObject], storedObject, @"Stored arrays with a single object should return the single object as opposed to the array. arrayForType: is used when an array is required");
            } else if ([(NSArray *)originalObject count] > 1 || [(NSArray *)originalObject count] == 0) {
                XCTAssertEqualObjects(nil, storedObject, @"objectForType: should return nil when attempting to retrieve an array or empty array. arrayForType: should be used to retrieve the array instead");
            }
        } else {
            XCTAssertEqualObjects(storedObject, originalObject, @"Stored object doesn't match original object. Class: '%@'", [originalObject class]);
        }
    }
}

- (void)testDisplayName
{
    NSString *name = @"Object Name";
    NSString *label = @"Object Label";
    QSObject *object = [QSObject makeObjectWithIdentifier:@"QSUnitTest:displayName"];
    [object setName:name];
    XCTAssertEqualObjects([object displayName], name, @"");
    [object setLabel:label];
    XCTAssertEqualObjects([object displayName], label, @"");
    [object setName:label];
    XCTAssertNil([object label], @"");
    XCTAssertEqualObjects([object displayName], label, @"");
}


- (void)testCombinedObjects
{
    QSObject *one = [QSObject objectWithString:@"one"];
    QSObject *two = [QSObject objectWithString:@"two"];
    QSObject *combined = [QSObject objectByMergingObjects:@[one, two]];
    XCTAssertEqual([combined count], (NSUInteger)2, @"");
    NSSet *originals = [NSSet setWithObjects:one, two, nil];
    NSSet *split = [NSSet setWithArray:[combined splitObjects]];
    XCTAssertEqualObjects(originals, split, @"");
    NSSet *originalStrings = [NSSet setWithObjects:@"one", @"two", nil];
    NSSet *stringValues = [NSSet setWithArray:[combined arrayForType:QSTextType]];
    XCTAssertEqualObjects(originalStrings, stringValues, @"");
}

- (void)testCacheExpiration
{
    // requires #1218
//    NSString *cacheKey = @"temporaryData";
//    NSString *data = @"string";
//    QSObject *object = [QSObject makeObjectWithIdentifier:@"QSUnitTest:tempCache"];
//    [object setObject:data forCache:cacheKey forTimeInterval:0.5];
//    STAssertEqualObjects(data, [object objectForCache:cacheKey], nil);
//    sleep(1);
//    STAssertNil([object objectForCache:cacheKey], nil);
}

@end
