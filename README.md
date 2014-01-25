Message Beast
===========
![alt tag](https://raw.github.com/rrbrambley/MessageBeast-Android/master/Images/yeti-Message-Beast-with-Shadow-smallish.png)

Message Beast is a robust app engine geared towards building single-user, non-social applications that rely on App.net [Messages](http://developers.app.net/docs/resources/message/) as a means of personal cloud storage. It is available for both Objective-C and [Android](https://github.com/rrbrambley/MessageBeast-Android). Some simple applications that could be built with Message Beast include:
* a to-do list, 
* a personal journal,
* an expense tracker,
* a time-tracking app (e.g. for contracters to track time to bill clients)

... and really any type of single-user utility app that would benefit from having data backed up to the cloud.

Typically, an application built with Message Beast might rely on one or more private App.net Channels as a means of storing Messages. In this context, try to think of a Message as a unit of data more akin to a row in a database table – not in the traditional way you hear the word "messages," i.e., like in a chat room.

Some key features of Message Beast are:

1. **Full Channel syncing**. Since Channels of data will be owned and accessed by a single user, there will typically be a relatively small amount of Messages (maybe between a few dozen and a few hundred). All Messages in a Channel can thus be synced and persisted to a sqlite database on your device, upon first launch. For new users of your application, this would more or less be a no-op, but for users switching between devices or platforms, you can ensure their data is easily synced and accessible.
2. **Offline Message support**. Messages can be created and used when offline. If no internet connection is available, then the unsent Messages can live happily alongside the sent Messages in the user interface. When an internet connection is eventually available, then the unsent Messages will be sent to the proper App.net Channel. No more progress spinners or long waits after hitting the "post" button in an app. This works for all types of Messages, including those with OEmbeds and file attachments.
3. **Mutable actions can be performed on Messages**. App.net supports the use of [Annotations](developers.app.net/docs/meta/annotations/) on Messages, but unfortunately they are not mutable. Message Beast introduces the concept of **Action Messages**, which work around this limitation. For example, in a journaling application, you might want to be able to mark a journal entry as a "favorite." And later, you might want to say it is no longer a "favorite." This can be achieved with Action Messages in Message Beast.
4. **Full text search**. All Messages stored in the sqlite database are candidates for full-text search. This means you can build features that let users easily find old Messages in an instant.
5. **Loads of other data lookups**. Other than full-text search, you can lookup messages by location, hashtag, date, or by occurrence of any Annotation that you wish.

Core Architecture
---------
Depending on your needs, you will then want to interface with one or more of the following:

* **AATTMessageManager**: This class provides the main Message lifecycle functionality, including retrieving, deleting, and creating new Messages. It wraps ADNKit's base functionality to perform these tasks, and seamlessly persists Messages and Message metadata as new Messages are encountered/created. It also provides the functionality associated with creating offline Messages and sending them at a later time. Furthermore, it interfaces with the SQLite database to provide simple methods for doing things like performing full-text searches, and obtaining instances of Messages in which specific hashtags, locations, other types of Annotations were used.
* **AATTActionMessageManager**: This class wraps the AATTMessageManager to support performing mutable actions via what Message Beast calls *Action Channels*. An Action Channel is a channel of type ``com.alwaysallthetime.action`` in which all Messages are [machine-only Messages](http://developers.app.net/docs/resources/message/#machine-only-messages), each with an Annotation that points to a *target* Message in your "main" Channel. An *Action Message* thus serves as a flag, indicating that the user performed a specific action on a Message (e.g. marked an entry as a favorite). The deletion of an Action Message corresponds to the undoing of the action on a Message. The ActionMessageManager is used to create Action Messages with the simple methods ``applyActionForActionChannelWithID:toTargetMessagePlus:`` and ``removeActionForActionChannelWithID:fromTargetMessagePlus:``.
* **AATTChannelSyncManager**: The AATTChannelSyncManager was created to compensate for the fact that you may end up using several Channels for any given application while working with this library (especially when working with Action Channels). To avoid having to make many method calls to retrieve the newest Messages in all these Channels simultaneously, you can use AATTChannelSyncManager and make a single method call to achieve this.

<p align="center">
  <img src="https://raw.github.com/rrbrambley/MessageBeast-Android/master/Images/ArchitectureDependency.png"/>
</p>

<h3>AATTMessagePlus</h3>
When working with these manager classes, you will most often be using **AATTMessagePlus** objects. AATTMessagePlus is a wrapper around ADNKits's ANKMessage class that adds extra functionality – including stuff for display locations, display dates, and features required to support unsent Messages. You will generally never need to construct AATTMessagePlus objects directly, as they will be given to you via the managers.

Example Code
------------

<h3>AATTChannelSyncManager</h3>
The easiest way to work with one or more Channels is to rely on AATTChannelSyncManager. This will do all the heavy lifting  associated with creating and initializing your private Channels, as well as performing full syncs on these Channels. Here's an example in which we will work with an [Ohai Journal Channel](https://github.com/appdotnet/object-metadata/blob/master/channel-types/net.app.ohai.journal.md):

```objective-c
//set up the query parameters to be used when making requests for my channel.
NSDictionary *parameters = @{@"include_deleted" : @0, @"include_machine" : @1,
                             @"include_message_annotations" : @1};

//create a channel spec for an Ohai Journal Channel.
AATTChannelSpec *spec = [[AATTChannelSpec alloc] initWithType:@"net.app.ohai.journal"
                                                 queryParameters:parameters];
AATTChannelSpecSet *specSet = [[AATTChannelSpecSet alloc] initWithChannelSpecs:@[spec]];

//clear the general parameters so that our code can set them on a per-channel basis
ANKClient *client = [ANKClient sharedClient];
client.generalParameters = nil;

//you can configure this all you want; read the docs for this.
AATTMessageManagerConfiguration *config = [[AATTMessageManagerConfiguration alloc] init];

AATTChannelSyncManager *channelSyncManager = [[AATTChannelSyncManager alloc] initWithClient:client 
                                             messageManagerConfiguration:config channelSpecSet:specSet];
[channelSyncManager initChannelsWithCompletionBlock:^(NSError *error) {
  if(!error) {
    //we're now ready to call fetchNewestMessagesWithCompletionBlock: whenevs.
  } else {
    //whoops
  }
}];
```

<h3>AATTMessageManager</h3>
The above code creates a new AATTMessageManager when the AATTChannelSyncManager is constructed. In more advanced use cases, you may wish to have an AATTMessageManager available without the use of an AATTChannelSyncManager. Regardless, you will only need one instance of a AATTMessageManager, so you may choose to create a singleton instance by doing something like this:

```objective-c
@implementation AATTMessageManagerInstance

+ (AATTMessageManager *)sharedInstance {
    static AATTMessageManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AATTMessageManagerConfiguration *config = [[AATTMessageManagerConfiguration alloc] init];

        //all Messages will be inserted into the sqlite 
        config.isDatabaseInsertionEnabled = YES;
        
        //location annotations will be examined and AATTDisplayLocations will be assigned to Messages
        config.isLocationLookupEnabled = YES;
        
        //a reference to all Messages with OEmbed Annotations will be stored in the sqlite database
        [config addAnnotationExtractionForAnnotationOfType:kANKCoreAnnotationEmbeddedMedia];
        
        //instead of relying only on ANKMessage.createdAt, use the Ohai display date annotation
        config.dateAdapter = ^NSDate *(ANKMessage *message) {
            NSDate *displayDate = [message ohaiDisplayDate];
            if(!displayDate) {
                displayDate = message.createdAt;
            }
            return displayDate;
        };
        ANKClient *client = [ANKClient sharedInstance];
        sharedInstance = [[AATTMessageManager alloc] initWithANKClient:client configuration:config];
    });
    
    return sharedInstance;
}

@end
```

And then you could choose to use this singleton instance to construct an AATTChannelSyncManager as well, if you wanted.

<h3>AATTActionMessageManager</h3>
If you'd like to build an app that supports mutable actions on Messages in your Channel, you should use the AATTActionMessageManager. Let's suppose you're working on a to-do list app that allows users to mark entries as "high-priority." Here's an example of how you might use the above AATTMessageManager singleton code to construct an AATTActionMessageManager that uses one Action Channel:

```objective-c
AATTMessageManager *messageManager = [AATTMessageManagerInstance sharedInstance];
AATTActionMessageManager actionMessageManager = [AATTActionMessageManager sharedInstanceWithMessageManager:messageManager];
[actionMessageManager initActionChannelWithType:"com.myapp.action.highpriority" targetChannel:myTodoChannel
                                                completionBlock:^(ANKChannel *actionChannel, NSError *error) {
    if(actionChannel) {
        //now we're ready to apply actions to myTodoChannel
        //let's stash this newly initialized Action Channel to be used later...
        self.highPriorityChannel = actionChannel;
    } else {
        NSLog(@"Could not init action channel with action type %@", actionType);
    }
}];
```

And later on you could allow the user to perform the high priority action on a Message by doing something like:

```objective-c
[actionMessageManager applyActionForChannelWithID:self.highPriorityChannel.channelID
                      toTargetMessagePlus:myMessagePlus];
```

And remove the action with:

```objective-c
[actionMessageManager removeActionForActionChannelWithID:self.highPriorityChannel.channelID
                      fromTargetMessageWithID:myMessagePlus.messageID];
```

Here's an example of how you could more easily work with your main to-do list Channel and your high-priority Action Channel by using the AATTChannelSyncManager:

```objective-c
//set up the query parameters to be used when making requests for my channel.
NSDictionary *parameters = @{@"include_deleted" : @0, @"include_machine" : @1,
                              @"include_message_annotations" : @1};
AATTChannelSpec *spec = [[AATTChannelSpec alloc] initWithType:@"com.myapp.todolist" queryParameters:parameters];
AATTTargetWithActionChannelSpecSet *specSet = 
  [[AATTTargetWithActionChannelSpecSet alloc] initWithTargetChannelSpec:spec
                                              actionChannelActionTypes:@[@"com.myapp.action.highpriority"]];
AATTActionMessageManager *actionMessageManager = [AATTActionMessageManagerInstance sharedInstance];
AATTChannelSyncManager syncManager = 
  [[AATTChannelSyncManager alloc]  initWithActionMessageManager:actionMessageManager 
                                  targetWithActionChannelsSpecSet:specSet];
[syncManager initChannelsWithCompletionBlock:^(NSError *error) {
  if(!error) {
    //we can now work with our channels!
    self.todoChannel = syncManager.targetChannel;
    self.highPriorityActionChannel = [syncManager.actionChannels objectForKey:@"com.myapp.action.highpriority"];
    
  } else {
    //whoops
  }
}];
```

License
-------
The MIT License (MIT)

Copyright (c) 2013 Rob Brambley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
