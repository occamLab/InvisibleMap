//
//  MemoryChecker.h
//  InvisibleMapCreator2
//
//  Created by tad on 7/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

#ifndef MemoryChecker_h
#define MemoryChecker_h
#import <Foundation/Foundation.h>

@interface MemoryChecker : NSObject
- (void) printRemainingMemory;
- (long) getRemainingMemory;
@end

#endif /* MemoryChecker_h */
