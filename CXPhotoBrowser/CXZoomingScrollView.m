//
//  CXZoomingScrollView.m
//  CXPhotoBrowserDemo
//
//  Created by ChrisXu on 13/4/19.
//  Copyright (c) 2013年 ChrisXu. All rights reserved.
//

#import "CXZoomingScrollView.h"
#import "CXPhotoBrowser.h"

#define PHOTO_LOADIG_VIEW_TAG 35271

@interface CXPhotoBrowser ()
- (UIImage *)imageForPhoto:(id<CXPhotoProtocol>)photo;

@end

@interface CXZoomingScrollView ()
{
    CGFloat zoomScaleFromInit;
    BOOL shouldSupportedPanGesture;
}
@property (nonatomic, assign) CXPhotoBrowser *photoBrowser;

- (void)checkPhotoLoadingView;

@end

@implementation CXZoomingScrollView
@synthesize photoBrowser = _photoBrowser, photo = _photo;

- (id)initWithPhotoBrowser:(CXPhotoBrowser *)browser
{
    if ((self = [super init]))
    {
        self.isPhotoSupportedPanGesture = YES;
        // Delegate
        self.photoBrowser = browser;
        
		// Tap view for background
		_tapView = [[CXTapDetectingView alloc] initWithFrame:self.bounds];
		_tapView.tapDelegate = self;
		_tapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_tapView.backgroundColor = [UIColor blackColor];
		[self addSubview:_tapView];
		
		// Image view
		_photoImageView = [[CXTapDetectingImageView alloc] initWithFrame:CGRectZero];
		_photoImageView.tapDelegate = self;
		_photoImageView.contentMode = UIViewContentModeCenter;
		_photoImageView.backgroundColor = [UIColor blackColor];
		[self addSubview:_photoImageView];
		
		// Setup
		self.backgroundColor = [UIColor blackColor];
		self.delegate = self;
		self.showsHorizontalScrollIndicator = NO;
		self.showsVerticalScrollIndicator = NO;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)layoutSubviews {
	
	// Update tap view frame
	_tapView.frame = self.bounds;
	
	// Super
	[super layoutSubviews];
	
    // Center the image as it becomes smaller than the size of the screen
    CGSize boundsSize = self.bounds.size;
    CGRect frameToCenter = _photoImageView.frame;
    
    // Horizontally
    if (frameToCenter.size.width < boundsSize.width) {
        frameToCenter.origin.x = floorf((boundsSize.width - frameToCenter.size.width) / 2.0);
	} else {
        frameToCenter.origin.x = 0;
	}
    
    // Vertically
    if (frameToCenter.size.height < boundsSize.height) {
        frameToCenter.origin.y = floorf((boundsSize.height - frameToCenter.size.height) / 2.0);
	} else {
        frameToCenter.origin.y = 0;
	}
    
	// Center
	if (!CGRectEqualToRect(_photoImageView.frame, frameToCenter))
    {
		_photoImageView.frame = frameToCenter;
        NSLog(@"%@",NSStringFromCGRect(frameToCenter));
	}
    
}

#pragma mark - Setter
- (void)setPhoto:(id<CXPhotoProtocol>)photo {
    _photoImageView.image = nil; // Release image
    if (_photo != photo)
    {
        _photo = photo;
    }
    
    if (_photo)
    {
        [self checkPhotoLoadingView];
        [self displayImage];
    }
}

#pragma mark - PV
- (void)checkPhotoLoadingView
{
    if (!_photoLoadingView)
    {
        if ([_photo photoLoadingView])
        {
            _photoLoadingView = (CXPhotoLoadingView *)[_photo photoLoadingView];
            [_photoLoadingView setTag:PHOTO_LOADIG_VIEW_TAG];
            [_photoLoadingView setFrame:_photoBrowser.view.bounds];
            _photoLoadingView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
            [self setUserInteractionEnabled:NO];
        }
        else
        {
            //default loading view
        }
    }
}

#pragma mark - PB
- (void)displayImageStartLoading
{
    [self checkPhotoLoadingView];
    if (![self viewWithTag:PHOTO_LOADIG_VIEW_TAG])
    {
        [self addSubview:_photoLoadingView];
        [_photoLoadingView displayLoading];
    }
    
//    [_photoLoadingView displayLoading];
}

- (void)displayImage
{
    if (_photo && !_photoImageView.image)
    {
		[_photoLoadingView removeFromSuperview];
        [self setUserInteractionEnabled:YES];
		// Reset
		self.maximumZoomScale = 1;
		self.minimumZoomScale = 1;
		self.zoomScale = 1;
		self.contentSize = CGSizeMake(0, 0);
		
		// Get image from browser as it handles ordering of fetching
		UIImage *img = [self.photoBrowser imageForPhoto:_photo];
		if (img)
        {
			// Set image
			_photoImageView.image = img;
			_photoImageView.hidden = NO;
			
			// Setup photo frame
			CGRect photoImageViewFrame;
			photoImageViewFrame.origin = CGPointZero;
			photoImageViewFrame.size = img.size;
			_photoImageView.frame = photoImageViewFrame;
			self.contentSize = photoImageViewFrame.size;
            
			// Set zoom to minimum zoom
			[self setMaxMinZoomScalesForCurrentBounds];
			
		}
        else
        {
			// Hide image view
			_photoImageView.hidden = YES;
		}
		[self setNeedsLayout];
	}
}

- (void)displayImageFailure
{
    [self checkPhotoLoadingView];
    if (![self viewWithTag:PHOTO_LOADIG_VIEW_TAG])
    {
        [self addSubview:_photoLoadingView];
    }
    
    [_photoLoadingView displayFailure];
}

- (void)setMaxMinZoomScalesForCurrentBounds
{
    // Reset
	self.maximumZoomScale = 1;
	self.minimumZoomScale = 1;
	self.zoomScale = 1;
	
	// Bail
	if (_photoImageView.image == nil) return;
	
	// Sizes
    CGSize boundsSize = self.bounds.size;
    CGSize imageSize = _photoImageView.frame.size;
    
    // Calculate Min
    CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
    CGFloat minScale = MIN(xScale, yScale);                 // use minimum of these to allow the image to become fully visible
	
	// If image is smaller than the screen then ensure we show it at
	// min scale of 1
	if (xScale > 1 && yScale > 1) {
		minScale = 1.0;
	}
    
	// Calculate Max
	CGFloat maxScale = 2.0; // Allow double scale
    // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
    // maximum zoom scale to 0.5.
	if ([UIScreen instancesRespondToSelector:@selector(scale)]) {
		maxScale = maxScale / [[UIScreen mainScreen] scale];
	}
	
	// Set
	self.maximumZoomScale = maxScale;
	self.minimumZoomScale = minScale;
	self.zoomScale = minScale;
	zoomScaleFromInit = minScale;
	// Reset position
	_photoImageView.frame = CGRectMake(0, 0, _photoImageView.frame.size.width, _photoImageView.frame.size.height);
	[self setNeedsLayout];
}

- (void)prepareForReuse
{
    shouldSupportedPanGesture = NO;
    self.photo = nil;
//    [_captionView removeFromSuperview];
//    self.captionView = nil;
}

#pragma mark - UIScrollViewDelegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return _photoImageView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.panGestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        NSLog(@"panGestureRecognizer Begin");
    }
    
    if (scrollView.panGestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        NSLog(@"panGestureRecognizer End");
    }
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view
{
    
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    shouldSupportedPanGesture = ((self.zoomScale == zoomScaleFromInit) && self.isPhotoSupportedPanGesture);
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    
}

#pragma mark - Touch Event
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
//    NSTimeInterval system = [[NSProcessInfo processInfo] systemUptime];
    
//    if (system - event.timestamp > 0.1) {
//        // not the event we were interested in
//    } else {
//        NSLog(@"Point: %@", NSStringFromCGPoint(point));
//        NSLog(@"View: %@", view);
//    }
    
    return view;
}


#pragma mark - CXTapDetectingImageViewDelegate

#pragma mark - CXTapDetectingViewDelegate

@end
