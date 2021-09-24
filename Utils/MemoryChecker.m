//
//  MemoryChecker.m
//  InvisibleMapCreator2
//
//  Created by Allison Li on 7/13/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <os/proc.h>
#import "MemoryChecker.h"

@implementation MemoryChecker
- (void) printRemainingMemory {
    NSString *memory = [NSString stringWithFormat: @"%ld", os_proc_available_memory()/(1024 * 1024)];
    NSLog(@"Remaining Memory: %@ MB", memory);
}
- (long) getRemainingMemory {
    return os_proc_available_memory()/(1024 * 1024);
}
@end
