/*

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

#import "FileBrowser.h"
#import "FileBrowser.m"
#import <UIKit/UIImageAndTextTableCell.h>

@implementation FileBrowser 
- (id)initWithFrame:(struct CGRect)frame{
	if ((self == [super initWithFrame: frame]) != nil) {
		UITableColumn *col = [[UITableColumn alloc]
			initWithTitle: @"FileName"
			identifier:@"filename"
			width: frame.size.width
		];
		float components[4] = {1.0, 1.0, 1.0, 1.0};
		struct CGColor *white = CGColorCreate(CGColorSpaceCreateDeviceRGB(), components);
		[self setBackgroundColor:white];
		_table = [[FileTable alloc] initWithFrame: CGRectMake(0, 48.0f, frame.size.width, frame.size.height - 48.0f)]; 
		[_table addTableColumn: col];
		[_table setSeparatorStyle: 1];
		[_table setDelegate: self];
		[_table setDataSource: self];
		[_table allowDelete:YES];
		_extensions = [[NSMutableArray alloc] init];
		_files = [[NSMutableArray alloc] init];
		_rowCount = 0;

		_delegate = nil;

		defaults = [[BooksDefaultsController alloc] init];
		[self addSubview: _table];
		[[NSNotificationCenter defaultCenter] 
		  addObserver:self
		  selector:@selector(shouldDeleteFileFromCell:)
		  name:SHOULDDELETEFILE
		  object:nil];
	}
	return self;
}

- (void)dealloc {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
	[_path release];
	[_files release];
	[_extensions release];
	[_table release];
	_delegate = nil;
	[super dealloc];
}

- (NSString *)path {
	return [[_path retain] autorelease];
}

- (void)setPath: (NSString *)path {
	[_path release];
	_path = [path copy];

	[self reloadData];
}

- (void)addExtension: (NSString *)extension {
	if (![_extensions containsObject:[extension lowercaseString]]) {
		[_extensions addObject: [extension lowercaseString]];
	}
}

- (void)setExtensions: (NSArray *)extensions {
	[_extensions setArray: extensions];
}

- (void)reloadData {
        BOOL isDir;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *tempArray = [[NSArray alloc] initWithArray:[fileManager directoryContentsAtPath:_path]];

	if ([fileManager fileExistsAtPath: _path] == NO) {
		return;
	}

	[_files removeAllObjects];

        NSString *file;
        NSEnumerator *dirEnum = [tempArray objectEnumerator];
	while (file = [dirEnum nextObject]) {
	  if ([file characterAtIndex:0] != (unichar)'.')
	    {  // Skip invisibles, like .DS_Store
	      if (_extensions != nil && [_extensions count] > 0) {
		NSString *extension = [[file pathExtension] lowercaseString];
		if ([_extensions containsObject: extension]) {
		  [_files addObject: file];
		}
		} else {
			[_files addObject: file];
		}
	    }
 	}

	[_files sortUsingFunction:&numberCompare context:NULL];
	_rowCount = [_files count];
	[_table reloadData];
	[tempArray release];
}

int numberCompare(id firstString, id secondString, void *context)
{
  int ret;
  BOOL underscoreFound = NO;
  unsigned int i;
  //This for loop is here because rangeOfString: was segfaulting
  for (i = ([firstString length]-1); i >= 0; i--)
    {
      if ([firstString characterAtIndex:i] == (unichar)'_')
	{
	  //NSLog(@"underscore at index: %d", i);	
	  underscoreFound = YES;
	  break;
	}
    }
  if (underscoreFound) //avoid MutableString overhead if possible
    {
  //Here's a lovely little kludge to make Baen Books' HTML
  //filenames sort correctly.
      unsigned int firstLength = [firstString length];
      unsigned int secondLength = [secondString length];
      NSMutableString *firstMutable = [[NSMutableString alloc] initWithString:firstString];
      NSMutableString *secondMutable = [[NSMutableString alloc] initWithString:secondString];
      [firstMutable replaceOccurrencesOfString:@"_" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, firstLength)];
      [secondMutable replaceOccurrencesOfString:@"_" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, secondLength)];

      ret = [firstMutable compare:secondMutable options:NSNumericSearch];
      [firstMutable release];
      [secondMutable release];
    }
  else
    {
      ret = [firstString compare:secondString options:NSNumericSearch];
    }
  return ret;
}

- (void)setDelegate:(id)delegate {
	_delegate = delegate;
}

- (int)numberOfRowsInTable:(UITable *)table {
	return _rowCount;
}

- (UITableCell *)table:(UITable *)table cellForRow:(int)row column:(UITableColumn *)col {
        BOOL isDir = NO;
	DeletableCell *cell = [[DeletableCell alloc] init];
	[cell setTitle: [[_files objectAtIndex: row] stringByDeletingPathExtension]];
	NSString *fullPath = [_path stringByAppendingPathComponent:[_files objectAtIndex:row]];
	[cell setPath:fullPath];
	if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir)
	  {
	     [cell setShowDisclosure:YES];
	     UIImage *coverart = nil;
	     coverart = [UIImage imageAtPath:[fullPath stringByAppendingPathComponent:@"cover.jpg"]];
	     if (nil == coverart)
	     {
	       coverart = [UIImage imageAtPath:[fullPath stringByAppendingPathComponent:@"cover.png"]];
	     }
	     if (nil != coverart)
	       {
		 struct CGImage *coverRef = [coverart imageRef];
		 int height = CGImageGetHeight(coverRef);
		 int width = CGImageGetWidth(coverRef);
		 if (height >= width)
		   {
		     float frac = (float)width / height;
		     width = (int)(46*frac);
		     height = 46;
		   }
		 else
		   {
		     float frac = (float)height / width;
		     height = (int)(46*frac);
		     width = 46;
		   }
		 //NSLog("new w: %d h: %d", width, height);
		 [cell setImage:coverart];
		 [[cell iconImageView] setFrame:CGRectMake(-10,0,width,height)];
	       }
	  }
	else if (![defaults scrollPointExistsForFile:fullPath])
	  //FIXME: It'd be great to have unread indicators for directories,
	  //a la podcast dirs & episodes.  For now, unread indicators only
	  //apply for text/HTML files.
	  {
	    UIImage *img = [UIImage applicationImageNamed:@"UnreadIndicator.png"];
	    [cell setImage:img];
	  }
	else // just to make things look nicer.
	  {
	    UIImage *img2 = [UIImage applicationImageNamed:@"ReadIndicator.png"];
	    [cell setImage:img2];
	    
	  }
	/*	//FIXME: This is an experiment
	UITableCellRemoveControl *remover = [[UITableCellRemoveControl alloc] initWithTarget:cell];
	[remover showRemoveButton:YES animated:YES];
	*/
	return cell;
}

- (void)tableRowSelected:(NSNotification *)notification {
  //NSLog(@"tableRowSelected!");
	if( [_delegate respondsToSelector:@selector( fileBrowser:fileSelected: )] )
		[_delegate fileBrowser:self fileSelected:[self selectedFile]];
}

- (NSString *)selectedFile {
	if ([_table selectedRow] == -1)
		return nil;

	return [_path stringByAppendingPathComponent: [_files objectAtIndex: [_table selectedRow]]];
}

- (void)selectCellForFilename:(NSString *)thePath
  // Please don't call this method!  It is here as an object lesson.

{
  NSString *filename = [thePath lastPathComponent];
  int i;
  for (i = 0; i < _rowCount ; i++)
    {
      if ([filename isEqualToString:[_files objectAtIndex:i]])
      {
	[_table selectRow:i byExtendingSelection:NO];
	return;
      }
    }
      NSLog(@"In theory we should never get here.");
      //In actuality, we in fact got an infinite loop.
}

- (NSString *)fileBeforeFileNamed:(NSString *)thePath
{
  int theRow = -1;
  NSString *filename = [thePath lastPathComponent];
  int i;
  for (i = 0; i < _rowCount ; i++)
    {
      if ([filename isEqualToString:[_files objectAtIndex:i]])
      {
	theRow = i;
      }
    }
  if (theRow < 1)
    return nil;

  return [_path stringByAppendingPathComponent: 
		  [_files objectAtIndex: theRow - 1]];
}


  - (NSString *)fileAfterFileNamed:(NSString *)thePath
{
  int theRow = -1;
  NSString *filename = [thePath lastPathComponent];
  int i;
  for (i = 0; i < _rowCount ; i++)
    {
      if ([filename isEqualToString:[_files objectAtIndex:i]])
      {
	theRow = i;
      }
    }
  if ((theRow < 0) || (theRow+1 >= _rowCount))
    return nil;

  return [_path stringByAppendingPathComponent: 
		  [_files objectAtIndex: theRow + 1]];
}

- (void)shouldDeleteFileFromCell:(NSNotification *)aNotification
{
  BOOL isDir = NO;
  DeletableCell *theCell = (DeletableCell *)[aNotification object];
  NSString *path = [theCell path];
  NSLog(@"Cell path: %@", path);
  if ([_files containsObject:[path lastPathComponent]])
    //FIXME:This could cause side effects in the rare case where a
    //FileBrowser contains cells with the same name!!!!
    {
      NSLog(@"_files contains %@", [path lastPathComponent]);
      if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir)
	{
	  [defaults removeScrollPointsForDirectory:path];
	}
      else
	[defaults removeScrollPointForFile:path];
      NSLog(@"_files before: %@", _files);
      BOOL success = [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
      if (success)
	{
	  [_files removeObject:[path lastPathComponent]];
	  _rowCount--;
	  [_table reloadData]; //erg...
	  NSLog(@"_files after: %@", _files);
	}
    }
  else
    NSLog(@"_files does not contain %@", [path lastPathComponent]);
}

@end
