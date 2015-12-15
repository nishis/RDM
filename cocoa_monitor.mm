//========================================================================
// GLFW 3.2 OS X - www.glfw.org
//------------------------------------------------------------------------
// Copyright (c) 2002-2006 Marcus Geelnard
// Copyright (c) 2006-2010 Camilla Berglund <elmindreda@elmindreda.org>
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would
//    be appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not
//    be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source
//    distribution.
//
//========================================================================

#import <stdlib.h>
#import <stdlib.h>
#import <limits.h>

#import <Foundation/Foundation.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <CoreVideo/CVBase.h>
#import <CoreVideo/CVDisplayLink.h>
#import <ApplicationServices/ApplicationServices.h>

#import "cocoa_monitor.h"

// Get the name of the specified display
//
// static char* getDisplayName(CGDirectDisplayID displayID)
// {
//     char* name;
//     CFDictionaryRef info, names;
//     CFStringRef value;
//     CFIndex size;
//
//     // NOTE: This uses a deprecated function because Apple has
//     //       (as of January 2015) not provided any alternative
//     info = IODisplayCreateInfoDictionary(CGDisplayIOServicePort(displayID),
//                                          kIODisplayOnlyPreferredName);
//     names = (CFDictionaryRef)CFDictionaryGetValue(info, CFSTR(kDisplayProductName));
//
//     if (!names || !CFDictionaryGetValueIfPresent(names, CFSTR("en_US"),
//                                                  (const void**) &value)) {
//         // This may happen if a desktop Mac is running headless
//         // _glfwInputError(GLFW_PLATFORM_ERROR,
//         //                 "Cocoa: Failed to retrieve display name");
//         NSLog(@"Failed to retrieve display name.");
//         CFRelease(info);
//         return strdup("Unknown");
//     }
//
//     size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value),
//                                              kCFStringEncodingUTF8);
//     name = (char *)calloc(size + 1, sizeof(char));
//     CFStringGetCString(value, name, size, kCFStringEncodingUTF8);
//     CFRelease(info);
//     return name;
// }

// Returns the io_service_t corresponding to a CG display ID, or 0 on failure.
// The io_service_t should be released with IOObjectRelease when not needed.
//
io_service_t IOServicePortFromCGDisplayID(CGDirectDisplayID displayID)
{
    io_iterator_t iter;
    io_service_t serv, servicePort = 0;

    CFMutableDictionaryRef matching = IOServiceMatching("IODisplayConnect");

    // releases matching for us
    kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                     matching,
                                                     &iter);
    if (err) {
        return 0;
    }

    while ((serv = IOIteratorNext(iter)) != 0) {
        CFDictionaryRef info;
        CFIndex vendorID, productID;
        CFNumberRef vendorIDRef, productIDRef;
        Boolean success;

        info = IODisplayCreateInfoDictionary(serv, kIODisplayOnlyPreferredName);

        vendorIDRef = (CFNumberRef)CFDictionaryGetValue(info, CFSTR(kDisplayVendorID));
        productIDRef = (CFNumberRef)CFDictionaryGetValue(info, CFSTR(kDisplayProductID));

        success = CFNumberGetValue(vendorIDRef, kCFNumberCFIndexType, &vendorID);
        success &= CFNumberGetValue(productIDRef, kCFNumberCFIndexType, &productID);

        if (!success) {
            CFRelease(info);
            continue;
        }

        // If the vendor and product id along with the serial don't match
        // then we are not looking at the correct monitor.
        // NOTE: The serial number is important in cases where two monitors
        //       are the exact same.
        if (CGDisplayVendorNumber(displayID) != vendorID  || CGDisplayModelNumber(displayID) != productID) {
            CFRelease(info);
            continue;
        }

        // The VendorID, Product ID, and the Serial Number all Match Up!
        // Therefore we have found the appropriate display io_service
        servicePort = serv;
        CFRelease(info);
        break;
    }
    IOObjectRelease(iter);
    return servicePort;
}

// Get the name of the specified display
//
// char* getDisplayName(CGDirectDisplayID displayID)
// {
//     char* name;
//     CFDictionaryRef info, names;
//     CFStringRef value;
//     CFIndex size;
//
//     // Supports OS X 10.4 Tiger and Newer
//     io_service_t serv = IOServicePortFromCGDisplayID(displayID);
//     if (serv == 0)
//     {
//         // _glfwInputError(GLFW_PLATFORM_ERROR,
//         //                 "Cocoa: IOServicePortFromCGDisplayID Returned an Invalid Port. (Port: 0)");
//         return strdup("Unknown");
//     }
//
//     info = IODisplayCreateInfoDictionary(serv, kIODisplayOnlyPreferredName);
//     IOObjectRelease(serv);
//
//     names = (CFDictionaryRef)CFDictionaryGetValue(info, CFSTR(kDisplayProductName));
//
//     if (!names || !CFDictionaryGetValueIfPresent(names, CFSTR("en_US"),
//                                                  (const void**) &value))
//     {
//         // This may happen if a desktop Mac is running headless
//         // _glfwInputError(GLFW_PLATFORM_ERROR,
//         //                 "Cocoa: Failed to retrieve display name");
//
//         CFRelease(info);
//         return strdup("Unknown");
//     }
//
//     size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value),
//                                              kCFStringEncodingUTF8);
//     name = (char *)calloc(size + 1, sizeof(char));
//     CFStringGetCString(value, name, size, kCFStringEncodingUTF8);
//
//     CFRelease(info);
//
//     return name;
// }
