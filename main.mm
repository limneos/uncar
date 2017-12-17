#if defined(__x86_64__) || defined(__i386__)
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#include <objc/runtime.h>
#include <sys/stat.h>

@interface CUINamedImage : NSObject
-(CGImageRef)image;
-(CGSize)size;
-(double)scale;
-(id)name;
-(CGImageRef)createImageFromPDFRenditionWithScale:(double)scale;
@end

@interface CUICatalog : NSObject
+(CUICatalog *)defaultUICatalogForBundle:(id)bundle;
-(id)initWithURL:(id)url error:(id*)error;
-(id)initWithName:(id)name fromBundle:(id)bundle error:(id*)error;
-(id)allImageNames;
-(id)imagesWithName:(id)name;
-(CUINamedImage*)imageWithName:(id)name scaleFactor:(double)factor;
-(CUINamedImage*)imageWithName:(id)name scaleFactor:(double)factor deviceIdiom:(int)idiom;
-(CUINamedImage*)imageWithName:(id)name scaleFactor:(double)factor displayGamut:(long long)gamut;
-(id)imageWithName:(id)arg1 scaleFactor:(double)arg2 displayGamut:(unsigned long long)arg3 layoutDirection:(long long)direction;

@end

int main(int argc, char **argv, char **envp) {
	
	NSBundle *CoreUI=[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/CoreUI.framework"];
	[CoreUI load];
	
	if (argc<3){
		printf(" Usage: uncar <bundle_path|carfile_path> <output_dir>\n");
		return 0;
	}

	char *bundlePath=argv[1];
	char *outputPath=argv[2];

	NSString *nsBundlePath=[NSString stringWithUTF8String:bundlePath];
	BOOL isCarFile = [[nsBundlePath lastPathComponent] hasSuffix:@"car"];

	NSBundle *bundleToExtract=[NSBundle bundleWithPath:nsBundlePath];
	NSString *outputPathString=NULL;
	
	if (isCarFile){
		outputPathString=[NSString stringWithFormat:@"%@/%@/%@",[NSString stringWithUTF8String:outputPath],[[nsBundlePath stringByDeletingLastPathComponent] lastPathComponent],[nsBundlePath lastPathComponent]];
	}
	else{
		outputPathString=[NSString stringWithFormat:@"%@/%@",[NSString stringWithUTF8String:outputPath],[nsBundlePath lastPathComponent]];
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:nsBundlePath]){
		printf(" %s %s not found",isCarFile ? "Bundle" : "car file", bundlePath);
		return 1;
	}
	
	NSError *error=NULL;

	CUICatalog *catalog=isCarFile ? [[objc_getClass("CUICatalog") alloc] initWithURL:[NSURL fileURLWithPath:[NSString stringWithUTF8String:bundlePath]] error:&error] : [objc_getClass("CUICatalog") defaultUICatalogForBundle:bundleToExtract];
	
	if (!catalog || error){
		catalog=[[objc_getClass("CUICatalog") alloc] initWithName:[[nsBundlePath lastPathComponent] stringByDeletingPathExtension] fromBundle:bundleToExtract error:&error];
	}
	
	if (!catalog){
		printf(" %s",[[error description] UTF8String]);
		return 1;
	}
	
	BOOL hasAnyFiles=[[catalog allImageNames] count]>0;

	if (!hasAnyFiles){
		printf(" Bundle %s does not contain any .car assets.\n",[[nsBundlePath lastPathComponent] UTF8String]); 
		return 0;
	}
	
	if (![[NSFileManager defaultManager] createDirectoryAtPath:outputPathString withIntermediateDirectories:YES attributes:0 error:&error]){
		printf(" %s",[[error description] UTF8String]);
		return 1;
	}
 	
	int count=0;
	
	for (NSString *name in [catalog allImageNames]){


		//lookup to unlock access, otherwise -> abort trap or hang:
		BOOL isDeviceIdiomFour=NO; // wtf is a device with idiom 4? // CarPlay related
		id lookup=[catalog imageWithName:name scaleFactor:0];

		if(!lookup){
			lookup=[catalog imageWithName:name scaleFactor:0 deviceIdiom:1];
		}
		if (!lookup){
			lookup=[catalog imageWithName:name scaleFactor:0 deviceIdiom:4];
			//continue;
			if (lookup){
				isDeviceIdiomFour=YES;
			}
		}
		if (!lookup){
			continue;
		}
		// did unlock access
		
#if defined(__x86_64__) || defined(__i386__)
		NSArray *allImagesForCurrentImage=[NSArray arrayWithObject:lookup] ;
#else
		NSArray *allImagesForCurrentImage=isDeviceIdiomFour ? [NSArray arrayWithObject:lookup] : [catalog imagesWithName:name];
#endif
		

		for (CUINamedImage * namedImage in allImagesForCurrentImage){
	
			if ([namedImage isKindOfClass:objc_getClass("CUINamedImage")]){
				NSString *imageName=[namedImage name];
				CGImageRef cgImage=[namedImage createImageFromPDFRenditionWithScale:[namedImage scale]];//[namedImage image];
				if (!cgImage){
					cgImage=[namedImage image];
				}
				if (!cgImage){
					continue;
				}
				int scale = [namedImage scale];
				//int width = [namedImage size].width;
				//int height = [namedImage size].height;
				int width=CGImageGetWidth(cgImage);
				int height=CGImageGetHeight(cgImage);
				NSString *outputFile=scale==1 ? [NSString stringWithFormat:@"%@-%d-%d.png",imageName,width,height] : [NSString stringWithFormat:@"%@-%d-%d-@%dx.png",imageName,width,height,scale];
				NSString *outputFilePath=[NSString stringWithFormat:@"%@/%@",outputPathString,outputFile];
				printf("Extracting %s\n",[outputFilePath UTF8String]);
#if defined(__x86_64__) || defined(__i386__)
				NSImage *image=[[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];
				NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
			   [rep setSize:[image size]];
			   [image release];
			   NSData *pngData = [rep representationUsingType:NSPNGFileType properties:@{}];
			   [pngData writeToFile:outputFilePath atomically:YES];
			   [rep release];
#else
				UIImage *image=[UIImage imageWithCGImage:cgImage];
				[UIImagePNGRepresentation(image) writeToFile:outputFilePath atomically:YES];
#endif
				count++;			
			}

		}
		
	}
	//printf("Extracted %d/%d files.\n",count,(int)[[catalog allImageNames] count]);
	printf("Extracted %d files.\n",count);
	
	return 0;
}

