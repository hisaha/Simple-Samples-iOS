#import <UIKit/UIKit.h>
#import <KudanAR/KudanAR.h>

@interface ViewController : ARCameraViewController

- (IBAction)arbiTrackButtonClicked:(id)sender;
@property () IBOutlet UIButton *arbiTrackButton;

@end

