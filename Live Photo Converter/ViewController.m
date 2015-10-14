//
//  ViewController.m
//  Live Photo Converter
//
//  Created by Jay Versluis on 14/10/2015.
//  Copyright © 2015 Pinkstone Pictures LLC. All rights reserved.
//

#import "ViewController.h"
@import Photos;
@import PhotosUI;
@import MobileCoreServices;
@import MediaPlayer;

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHLivePhotoViewDelegate>

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *workingIndicator;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)grabVideo:(id)sender {
    
    // create an image picker
    UIImagePickerController *picker = [[UIImagePickerController alloc]init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.delegate = self;
    
    // make sure we include Live Photos (otherwise we'll only get UIImages)
    NSArray *mediaTypes = @[((NSString *)kUTTypeMovie)];
    picker.mediaTypes = mediaTypes;
    
    // bring up the picker
    [self presentViewController:picker animated:YES completion:nil];
}

- (IBAction)sharePhoto:(id)sender {

    // if we don't have a photo view, present warning and return
    if (![self.view viewWithTag:87]) {
        [self cannotShareLivePhotoWarning];
        return;
    }
    
    // grab a reference to the Photo View and Live Photo
    PHLivePhotoView *photoView = (PHLivePhotoView *)[self.view viewWithTag:87];
    PHLivePhoto *livePhoto = photoView.livePhoto;
    
    // build an activity view controller
    UIActivityViewController *activityView = [[UIActivityViewController alloc]initWithActivityItems:@[livePhoto] applicationActivities:nil];
    [self presentViewController:activityView animated:YES completion:^{
        // let's see if we need to do anything here
        NSLog(@"Activity View Controller has finidhed.");
    }];
}

- (void)cannotShareLivePhotoWarning {
    
    // create an alert view
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Live Photo to share" message:@"There's nothing showing in the Live Photo View, so you can't share anything. Convert a video first and try again." preferredStyle:UIAlertControllerStyleAlert];
    
    // add a single action
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"Thanks ;-)" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:action];
    
    // and display it
    [self presentViewController:alert animated:YES completion:nil];
}

- (PHLivePhoto *)convertLivePhotoFromVideoURL:(NSURL *)videoURL photoURL:(NSURL *)photoURL {
    
    // courtesy of Genady Okrain:
    // https://realm.io/news/hacking-live-photos-iphone-6s/
    // https://github.com/genadyo/LivePhotoDemo/
    
    CGSize targetSize = CGSizeZero;
    PHImageContentMode contentMode = PHImageContentModeDefault;
    
    // call scary Private API to create the live photo
    PHLivePhoto *livePhoto = [[PHLivePhoto alloc] init];
    SEL initWithImageURLvideoURL = NSSelectorFromString(@"_initWithImageURL:videoURL:targetSize:contentMode:");
    
    if ([livePhoto respondsToSelector:initWithImageURLvideoURL]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[livePhoto methodSignatureForSelector:initWithImageURLvideoURL]];
        [invocation setSelector:initWithImageURLvideoURL];
        [invocation setTarget:livePhoto];
        [invocation setArgument:&(photoURL) atIndex:2];
        [invocation setArgument:&(videoURL) atIndex:3];
        [invocation setArgument:&(targetSize) atIndex:4];
        [invocation setArgument:&(contentMode) atIndex:5];
        [invocation invoke];
    }
    
    return livePhoto;
}

- (UIImage *)thumbnailForVideoURL:(NSURL *)videoURL atTime:(NSTimeInterval)time {
    
    // courtesy of memmons
    // http://stackoverflow.com/questions/1518668/grabbing-the-first-frame-of-a-video-from-uiimagepickercontroller
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetIG =
    [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetIG.appliesPreferredTrackTransform = YES;
    assetIG.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    NSError *igError = nil;
    thumbnailImageRef =
    [assetIG copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60)
                    actualTime:NULL
                         error:&igError];
    
    if (!thumbnailImageRef)
        NSLog(@"thumbnailImageGenerationError %@", igError );
    
    UIImage *thumbnailImage = thumbnailImageRef
    ? [[UIImage alloc] initWithCGImage:thumbnailImageRef]
    : nil;
    
    return thumbnailImage;
}

- (void)noVideoWarning {
    
    // create an alert view
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Not a Video" message:@"Sadly this is not a video file, so we can't show or convert it. Try another one." preferredStyle:UIAlertControllerStyleAlert];
    
    // add a single action
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"Thanks, Phone!" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:action];
    
    // and display it
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSURL*)grabFileURL:(NSString *)fileName {
    
    // find Documents directory
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    
    // append a file name to it
    documentsURL = [documentsURL URLByAppendingPathComponent:fileName];
    
    return documentsURL;
}

#pragma mark - Image Picker Delegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    
    // dismiss the picker
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
    // dismiss the picker
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // if we have a live photo view already, remove it
    if ([self.view viewWithTag:87]) {
        UIView *subview = [self.view viewWithTag:87];
        [subview removeFromSuperview];
    }
    
    // grab the video
    NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
    
    // grab a still image from the video (we'll use the first frame)
    AVURLAsset *asset = [[AVURLAsset alloc]initWithURL:videoURL options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    UIImage *image = [UIImage imageWithCGImage:[generator copyCGImageAtTime:CMTimeMake(0, 1) actualTime:nil error:nil]];
    
    // or use
    // UIImage *image = [self thumbnailForVideoURL:videoURL atTime:0];
    
    // turn UIImage into an NSURL (not needed)
    UIImageWriteToSavedPhotosAlbum(image, self, nil, nil);
    
    // we need a URL for the image, so we'll save it to the Documents Directory
    NSURL *photoURL = [self grabFileURL:@"tempPhoto"];
    NSData *data = UIImagePNGRepresentation(image);
    [data writeToURL:photoURL atomically:YES];
    
    // now grab the Live Photo (takes some time, bring up spinning wheel)
    [self.workingIndicator startAnimating];
    PHLivePhoto *livePhoto = [self convertLivePhotoFromVideoURL:videoURL photoURL:photoURL];
    
    
//    // create an image view
//    UIImageView *imageView = [[UIImageView alloc]initWithFrame:self.view.bounds];
//    imageView.image = image;
//    imageView.contentMode = UIViewContentModeScaleAspectFit;
//    imageView.tag = 87;
//    [self.view addSubview:imageView];
    
    
    // create a Live Photo View
    PHLivePhotoView *photoView = [[PHLivePhotoView alloc]initWithFrame:self.view.bounds];
    // photoView.livePhoto = [info objectForKey:UIImagePickerControllerLivePhoto];
    photoView.livePhoto = livePhoto;
    photoView.contentMode = UIViewContentModeScaleAspectFit;
    photoView.tag = 87;
    
    // bring up the Live Photo View
    [self.view addSubview:photoView];
    [self.view sendSubviewToBack:photoView];
    [self.workingIndicator stopAnimating];
}

#pragma mark - Live Photo VIew Delegate

@end
