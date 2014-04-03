Message Beast
===========
![alt tag](https://raw.github.com/rrbrambley/MessageBeast-Android/master/Images/yeti-Message-Beast-with-Shadow-smallish.png)

*Note: Documentation still incomplete. Code is highly functional, but small implementation changes still to come.*

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

<h3>Loading Persisted Messages</h3>
The AATTMessageManager's fetch methods will always only fetch Messages that it does not currently have persisted. If you want to load persisted Messages, e.g. on app launch, you should:

```objective-c
//load up to 50 Messages in my channel.
NSOrderedDictionary *messages = [messageManager loadPersistedMesssageForChannelWithID:myChannel.channelID
                                                limit:50];
```

When you load persisted Messages, the Message's stay available in the AATTMessageManager's internal Message map. This means that subsequent calls to loadPersistedMesssageForChannelWithID:limit: will load *more* Messages (e.g. Mesasges 0-49 in first call above, then 50-99 in second call). If you don't need the Messages to be kept in memory, you should use one of the ``persistedMessagesForChannelWithID`` methods.

<h3>Full Channel Sync</h3>
Having all a user's data available on their device (versus in the cloud) might be necessary to make your app function properly. If this is the case, you might want to use one of the following methods of syncing the user's data.

With AATTChannelSyncManager:

```objective-c
//assume we have instantiated AATTChannelSyncManager as it was in the example, above

[channelSyncManager initChannelsWithCompletionBlock:^(NSError *error) {
  if(!error) {
    //now that we've initialized our channels, we can perform a sync.
    
    [channelSyncManager checkFullSyncStatusWithStartBlock:^{
      //show progress or something (e.g. "Retrieving your data...")
      //this will only be called if your channel hasn't already been synced once before
      
    } completionBlock:^(NSError *error) {
      //this will be called instantly if the channel has already been synced once.
      //
      //otherwise, the startBlock will be called first, and this will eventually be called
      //after all Messages have been downloaded and persisted.
      
    }];
  }
}];
```

Using AATTChannelSyncManager to perform the full sync is especially convenient when you are syncing multiple Channels (e.g. three Action Channels along with your single target Channel) – all of the Channels will be synced with a single method call. Alternatively, if you can use AATTMessageManager's methods to directly check the sync state of your Channel and start the sync if necessary (this is what AATTChannelSyncManager does under the hood):

```objective-c
AATTChannelFullSyncState state = [messageManager fullSyncStateForChannelWithID:myChannel.channelID];
if(state == AATTChannelFullSyncStateNotStarted ||
   state == AATTChannelFullSyncStateStarted) {
   [messageManager fetchAndPersistAllMessagesInChannels:@[myChannel]
                   completionBlock:^(BOOL success, NSError *error) {
      if(!error) {
        //done!
      } else {
        //sad face
      }
   }];
} else {
  //we're already done, carry on by launching the app normally
}
```

It's worth noting that ``fetchAndPersistAllMessagesInChannels:completionBlock:`` actually will sync multiple Channels at once, just like the AATTChannelSyncManager, but the main difference is that the AATTChannelSyncManager provides feedback via the start block after it internally checks the state.

<h3>Message Creation and Lifecycle</h3>
AATTMessageManager provides a few different ways of creating Messages. The simplest way is:

```objective-c
ANKMessage *m = [[ANKMessage alloc] init];
m.text = @"pizza party!";

[myMessageManager createMessageInChannelWithID:myChannel.channelID message:m
                  completionBlock:^(NSArray *messagePlusses, BOOL appended, 
                                    ANKAPIResponseMeta *meta, NSError *error) {
  if(!error) {
    //messages includes our new MessagePlus, and MessagePlusses for any other Message that may 
    //have not already been synced prior to creating this new one.
    //
    //appended does not apply in this case (true if the Messages are added to the end of the 
    //Channel's Messages, false if they are prepended).
  } else {
    //sadface
  }
}];
```

This a thin wrapper around ADNKit's createMessage:inChannelWithID:completion: method that performs database insertion and extraction of other Message data (just as would happen when calling the fetch methods).

For applications that should enable users to create Messages regardless of having an internet connection, you can use a different method:

```objective-c
ANKMessage *message = [[ANKMessage alloc] init];
message.text = @"pizza party!";

[myMessageManager createUnsentMessageAndAttemptSendInChannelWithID:myChannel.channelID message:mesage];
```

The first obvious difference between this method of creating a Message and the previous is that you do not pass a completion block when creating an unsent Message. Instead, because the Message could be sent at a later time, you should use NSNotificationCenter to listen for the AATTMessageManagerDidSendUnsentMessagesNotification elsewhere in your app.

```objective-c
//probably when my View Controller is being initialized or something
[[NSNotificationCenter defaultCenter] addObserver:self 
                                      selector:@selector(didSendUnsentMessages:) 
                                      name:AATTMessageManagerDidSendUnsentMessagesNotification object:nil];

...

//and then elsewhere...
- (void)didSendUnsentMessages:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *channelID = [userInfo objectForKey:@"channelID"];
    NSArray *messageIDs = [userInfo objectForKey:@"messageIDs"];
    NSArray *replacementMessageIDs = [userInfo objectForKey:@"replacementMessageIDs"];

    //the sent messageIDs were replaced with the messages at corresponding indices
    //in replacementMessageIDs. Use that to update any UI, etc. if necessary.
    //
}
```
You may also choose to listen to the ``AATTMessageManagerDidFailToSendUnsentMessagesNotification`` to find out when messages do not send successfully. The userInfo will contain the keys ``channelID``, ``messageID``, and ``sendAttemptsCount``.

If your Message depends on the existence of [File](developers.app.net/docs/resources/file/) objects for [OEmbeds](https://github.com/appdotnet/object-metadata/blob/master/annotations/net.app.core.oembed.md) or [attachments](https://github.com/appdotnet/object-metadata/blob/master/annotations/net.app.core.attachments.md), you can also create unsent Messages with pending file uploads. Pending files are added to the ``AATTADNFileManager`` and  then you use the createUnsentMessageAndAttemptSendInChannelWithID:message:pendingFileAttachments: method.

```objective-c
AATTPendingFile *pendingFile = [AATTPendingFile pendingFileWithFileAtURL:self.myFileURL];
pendingFile.isPublic = NO;
pendingFile.type = @"com.sweetapp.bro";
pendingFile.name = @"monster_trux.jpg";
[[AATTADNFileManagerInstance sharedInstance] addPendingFile:pendingFile];

//create a pending file attachment using our new pending file
NSArray *attachments = @[[[AATTPendingFileAttachment alloc] initWithPendingFileID:pendingFile.ID isOEmbed:YES]]];

[self.messageManager createUnsentMessageAndAttemptSendInChannelWithID:myChannel.channelID
                     message:message pendingFileAttachments:attachments];
```

When Messages fail to send on their first attempt, you need to trigger another send attempt before any AATTMessageManager's fetch methods can be executed. For example, ``fetchNewestMessagesInChannelWithID:completionBlock:`` will return NO if unsent Messages are blocking the newest Messages from being retrieved.

```objective-c
//this will send both pending Message deletions and unsent Messages
[self.messageManager sendAllUnsentForChannelWithID:myChannel.channelID];
```
<h3>Message Search and Lookup</h3>
Full-text search is available for all Messages persisted by AATTMessageManager. 

```objective-c
AATTOrderedMessageBatch *results = [self.messageManager searchMessagesWithQuery:@"pizza"
                                                        inChannelWithID:myChannel.channelID];
//Message NSDates mapped to AATTMessagePlus objects, in reverse chronological order
NSOrderedDictionary *messages = results.messagePlusses;
```

Because location Annotations are not part of the Message text, the human-readable name of all display locations are indexed separately. To search by human-readable location name, use:

```objective-c
//find MessagePlus objects that have a DisplayLocation name matching "the mission"
AATTOrderedMessageBatch *results = [self.messageManager searchMessagesWithQuery:@"the mission"
                                                        inChannelWithID:myChannel.channelID];
```

Other methods available for looking up Messages:

```objective-c
//all messages in my channel that use the OEmbed Annotation
NSOrderedDictionary *annotations = [self.messageManager persistedMessagesForChannelWithID:myChannel.channelID
                                                     annotationType:@"net.app.core.oembed"];

//all messages in my channel that have the hashtag "food"
NSOrderedDictionary *hashtags = [self.messageManager persistedMessagesForChannelWithID:myChannel.channelID
                                                     hashtagName:@"food"];

//all messages in my channel that have an AATTDisplayLocation with the same name as that of myMessagePlus,
//and that lie within ~one hundred meters of that AATTDisplayLocation (e.g. McDonald's in San Francisco is not
//the same McDonald's in Chicago).
NSOrderedDictionary *locations = [self.messageManager persistedMessagesForChannelWithID:myChannel.channelID
                                                      displayLocation:myMessagePlus.displayLocation
                                                      locationPrecision:AATTLocationPrecisionOneHundredMeters];
```

<h3>Other Goodies</h3>
Use the ANKClient+ANKConfigurationHelper category on every launch to update the ANKConfiguration as per the [App.net Configuration guidelines](http://developers.app.net/docs/resources/config/#how-to-use-the-configuration-object):

```objective-c
//use this category method somewhere when app launches. This will update at most once per day.
[appDotNetClient updateConfigurationIfDueWithCompletion:^(BOOL didUpdate) {
    
}];

...

//elsewhere, when configuration is needed
ANKConfiguration *configuration = [AATTADNPersistence configuration];

```

Future Improvements, Additions, Fixes
------
See [Issues](https://github.com/rrbrambley/MessageBeast-ObjC/issues).


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
