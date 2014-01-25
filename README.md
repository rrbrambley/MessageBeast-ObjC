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
