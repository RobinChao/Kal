/*
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

#import <CoreGraphics/CoreGraphics.h>

#import "KalGridView.h"
#import "KalView.h"
#import "KalMonthView.h"
#import "KalTileView.h"
#import "KalLogic.h"
#import "KalDate.h"
#import "KalPrivate.h"
#import "NSDate+Convenience.h"

#define SLIDE_NONE 0
#define SLIDE_UP 1
#define SLIDE_DOWN 2

const CGSize kTileSize = { 46.f, 44.f };

static NSString *kSlideAnimationId = @"KalSwitchMonths";

@interface KalGridView ()

@property (nonatomic, strong) NSMutableArray *highligthedTiles;
@property (nonatomic, strong) KalDate *beginDate;
@property (nonatomic, strong) KalDate *endDate;

- (void)swapMonthViews;

@end

@implementation KalGridView

- (void)setBeginDate:(KalDate *)beginDate
{
    KalTileView *preTile = [frontMonthView tileForDate:_beginDate];
    preTile.selected = NO;
    _beginDate = beginDate;
    KalTileView *currentTile = [frontMonthView tileForDate:_beginDate];
    currentTile.selected = YES;
    [self removeHighlights];
    self.endDate = nil;
}

- (void)setEndDate:(KalDate *)endDate
{
    KalTileView *beginTile = [frontMonthView tileForDate:self.beginDate];
    beginTile.selected = YES;
    
    KalTileView *preTile = [frontMonthView tileForDate:_endDate];
    preTile.selected = NO;
    _endDate = endDate;
    KalTileView *currentTile = [frontMonthView tileForDate:_endDate];
    currentTile.selected = YES;
    
    KalDate *realBeginDate;
    KalDate *realEndDate;
    
    [self removeHighlights];
    
    if ([self.endDate compare:self.beginDate] == NSOrderedSame) {
        return;
    } else if ([self.beginDate compare:self.endDate] == NSOrderedAscending) {
        realBeginDate = self.beginDate;
        realEndDate = self.endDate;
    } else {
        realBeginDate = self.endDate;
        realEndDate = self.beginDate;
    }
    
    int dayCount = [NSDate dayBetweenStartDate:[realBeginDate NSDate] endDate:[realEndDate NSDate]];
    for (int i=1; i<dayCount; i++) {
        NSDate *nextDay = [[realBeginDate NSDate] offsetDay:i];
        KalTileView *nextTile = [frontMonthView tileForDate:[KalDate dateFromNSDate:nextDay]];
        if (nextTile) {
            nextTile.highlighted = YES;
            [nextTile setNeedsDisplay];
            [self.highligthedTiles addObject:nextTile];
        }
    }
}

- (void)removeHighlights
{
    for (KalTileView *tile in self.highligthedTiles) {
        tile.highlighted = NO;
    }
    [self.highligthedTiles removeAllObjects];
}

- (id)initWithFrame:(CGRect)frame logic:(KalLogic *)theLogic delegate:(id<KalViewDelegate>)theDelegate
{
    // MobileCal uses 46px wide tiles, with a 2px inner stroke
    // along the top and right edges. Since there are 7 columns,
    // the width needs to be 46*7 (322px). But the iPhone's screen
    // is only 320px wide, so we need to make the
    // frame extend just beyond the right edge of the screen
    // to accomodate all 7 columns. The 7th day's 2px inner stroke
    // will be clipped off the screen, but that's fine because
    // MobileCal does the same thing.
    frame.size.width = 7 * kTileSize.width;
    
    if (self = [super initWithFrame:frame]) {
        self.clipsToBounds = YES;
        logic = theLogic;
        delegate = theDelegate;
        
        CGRect monthRect = CGRectMake(0.f, 0.f, frame.size.width, frame.size.height);
        frontMonthView = [[KalMonthView alloc] initWithFrame:monthRect];
        backMonthView = [[KalMonthView alloc] initWithFrame:monthRect];
        backMonthView.hidden = YES;
        [self addSubview:backMonthView];
        [self addSubview:frontMonthView];
        
        self.selectionMode = KalSelectionModeSingle;
        _highligthedTiles = [[NSMutableArray alloc] init];
        
        [self jumpToSelectedMonth];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    [[UIImage imageNamed:@"Kal.bundle/kal_grid_background.png"] drawInRect:rect];
    [[UIColor colorWithRed:0.63f green:0.65f blue:0.68f alpha:1.f] setFill];
    CGRect line;
    line.origin = CGPointMake(0.f, self.height - 1.f);
    line.size = CGSizeMake(self.width, 1.f);
    CGContextFillRect(UIGraphicsGetCurrentContext(), line);
}

- (void)sizeToFit
{
    self.height = frontMonthView.height;
}

#pragma mark -
#pragma mark Touches

//- (void)setHighlightedTiles:(NSArray *)tiles
//{
//  if (highlightedTile != tile) {
//    highlightedTile.highlighted = NO;
//    highlightedTile = [tile retain];
//    tile.highlighted = YES;
//    [tile setNeedsDisplay];
//  }
//    for (KalTileView *tile in tiles) {
//        tile.highlighted = YES;
//        [tile setNeedsDisplay];
//    }
//}

- (void)setSelectedTiles:(KalTileView *)tile
{
    tile.selected = YES;
    [delegate didSelectDate:tile.date];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    UIView *hitView = [self hitTest:location withEvent:event];
    
    if (!hitView)
        return;
    
    if ([hitView isKindOfClass:[KalTileView class]]) {
        KalTileView *tile = (KalTileView*)hitView;
        if (tile.type & KalTileTypeDisable)
            return;
        
        KalDate *date = tile.date;
        if ([date compare:self.beginDate] == NSOrderedSame) {
            date = self.beginDate;
            _beginDate = _endDate;
            _endDate = date;
        } else if ([date compare:self.endDate] == NSOrderedSame) {
            
        } else {
            self.beginDate = date;
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.selectionMode == KalSelectionModeSingle)
        return;
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    UIView *hitView = [self hitTest:location withEvent:event];
    
    if (!hitView)
        return;
    
    if ([hitView isKindOfClass:[KalTileView class]]) {
        KalTileView *tile = (KalTileView*)hitView;
        if (tile.type & KalTileTypeDisable)
            return;
        
        KalDate *endDate = tile.date;
        if ([endDate compare:self.beginDate] == NSOrderedSame || [endDate compare:self.endDate] == NSOrderedSame)
            return;
        if (tile.isFirst || tile.isLast) {
            if ([tile.date compare:[KalDate dateFromNSDate:logic.baseDate]] == NSOrderedDescending) {
                [delegate showFollowingMonth];
            } else {
                [delegate showPreviousMonth];
            }
        }
        self.endDate = endDate;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    UIView *hitView = [self hitTest:location withEvent:event];
    
    if ([hitView isKindOfClass:[KalTileView class]]) {
        KalTileView *tile = (KalTileView*)hitView;
        if (tile.type & KalTileTypeDisable)
            return;
        
        if ((self.selectionMode == KalSelectionModeSingle && tile.belongsToAdjacentMonth) ||
            (self.selectionMode == KalSelectionModeRange && (tile.isFirst || tile.isLast))) {
            if ([tile.date compare:[KalDate dateFromNSDate:logic.baseDate]] == NSOrderedDescending) {
                [delegate showFollowingMonth];
            } else {
                [delegate showPreviousMonth];
            }
        }
        if (self.selectionMode == KalSelectionModeRange) {
            KalDate *endDate = tile.date;
            if ([tile.date compare:self.beginDate] == NSOrderedSame) {
                NSDate *endNSDate = [endDate NSDate];
                if ([[endNSDate offsetDay:1] compare:self.maxAVailableDate] == NSOrderedDescending) {
                    endDate = [KalDate dateFromNSDate:[endNSDate offsetDay:-1]];
                } else {
                    endDate = [KalDate dateFromNSDate:[endNSDate offsetDay:1]];
                }
            }
            self.endDate = endDate;
        }
    }
}

#pragma mark -
#pragma mark Slide Animation

- (void)swapMonthsAndSlide:(int)direction keepOneRow:(BOOL)keepOneRow
{
    backMonthView.hidden = NO;
    
    // set initial positions before the slide
    if (direction == SLIDE_UP) {
        backMonthView.top = keepOneRow
        ? frontMonthView.bottom - kTileSize.height
        : frontMonthView.bottom;
    } else if (direction == SLIDE_DOWN) {
        NSUInteger numWeeksToKeep = keepOneRow ? 1 : 0;
        NSInteger numWeeksToSlide = [backMonthView numWeeks] - numWeeksToKeep;
        backMonthView.top = -numWeeksToSlide * kTileSize.height;
    } else {
        backMonthView.top = 0.f;
    }
    
    // trigger the slide animation
    [UIView beginAnimations:kSlideAnimationId context:NULL]; {
        [UIView setAnimationsEnabled:direction!=SLIDE_NONE];
        [UIView setAnimationDuration:0.5];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
        
        frontMonthView.top = -backMonthView.top;
        backMonthView.top = 0.f;
        
        frontMonthView.alpha = 0.f;
        backMonthView.alpha = 1.f;
        
        self.height = backMonthView.height;
        
        [self swapMonthViews];
    } [UIView commitAnimations];
    [UIView setAnimationsEnabled:YES];
}

- (void)slide:(int)direction
{
    self.transitioning = YES;
    
    [backMonthView showDates:logic.daysInSelectedMonth
        leadingAdjacentDates:logic.daysInFinalWeekOfPreviousMonth
       trailingAdjacentDates:logic.daysInFirstWeekOfFollowingMonth
            minAvailableDate:self.minAvailableDate
            maxAvailableDate:self.maxAVailableDate];
    
    // At this point, the calendar logic has already been advanced or retreated to the
    // following/previous month, so in order to determine whether there are
    // any cells to keep, we need to check for a partial week in the month
    // that is sliding offscreen.
    
    BOOL keepOneRow = (direction == SLIDE_UP && [logic.daysInFinalWeekOfPreviousMonth count] > 0)
    || (direction == SLIDE_DOWN && [logic.daysInFirstWeekOfFollowingMonth count] > 0);
    
    [self swapMonthsAndSlide:direction keepOneRow:keepOneRow];
    
    self.endDate = _endDate;
}

- (void)slideUp { [self slide:SLIDE_UP]; }
- (void)slideDown { [self slide:SLIDE_DOWN]; }

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
    self.transitioning = NO;
    backMonthView.hidden = YES;
}

#pragma mark -

- (void)selectDate:(KalDate *)date
{
    //  self.selectedTile = [frontMonthView tileForDate:date];
}

- (void)swapMonthViews
{
    KalMonthView *tmp = backMonthView;
    backMonthView = frontMonthView;
    frontMonthView = tmp;
    [self exchangeSubviewAtIndex:[self.subviews indexOfObject:frontMonthView] withSubviewAtIndex:[self.subviews indexOfObject:backMonthView]];
}

- (void)jumpToSelectedMonth
{
    [self slide:SLIDE_NONE];
}

- (void)markTilesForDates:(NSArray *)dates { [frontMonthView markTilesForDates:dates]; }

//- (KalDate *)selectedDate { return self.endTile.date; }

#pragma mark -


@end
