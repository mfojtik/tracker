GIT Tracker
==============

Installation and usage
-------------

* <code>$ gem install tracker-client</code>

* <code>$ git clone git://github.com/mifo/tracker.git</code>
* <code>$ cd tracker</code>
* <code>$ bundle</code>
* <code>$ rackup config.ru</code>

This will start the web server on port 9292. Now navigate to [http://localhost:9292/patches](http://localhost:9292/patches).
The page appears to be empty, because you don't have any patches recorded yet.

Now choose a GIT repo from where you want to record your patches. That repo
should have a designated branch with your work checked out (it should be the current working branch).

Now you can record the patches (<em>the -d part is optional, when omitted, current
working directory is used instead</em>:

* <code>$ tracker record -d PATH_TO_YOUR_GIT_REPO</code>

Then you may refresh the blank web page and you should see something like this:

![img1](http://omicron.mifo.sk/tracker_1.png)

Good. You have just recorded your patches, so now you don't loose track of them.
Go ahead, send your patches to the mailing list, and find someone who will review your patches.

If the person is happy about what you did, and wants to give you an ACK, then he can do it by:

* <code>$ tracker ack -d PATH_TO_REVIEWER_GIT_REPO</code>

NOTE: He must have the branch with applied patches set as 'current', so tracker can
read the history and get the patch hashes.

Now if you refresh the web page, you will see that all patches are marked by
'ACK' and are green:

![img2](http://omicron.mifo.sk/tracker_2.png)

That means, they are good to go. Lets push them. Before push, you may indicate,
that you're going to push them:

* <code>$ tracker push -d PATH_TO_YOUR_REPO</code>

The patches will get the 'PUSH' stamp and tracker job is done here. You may push
your patches to remote GIT repository now :-)

<b>Patchset revisions:</b>

Tracker now support 'obsoleting' patch sets when they are 're-sent' (ie. new
revision of the same patch set is sent to list). To obsolete particular patch
set, you first need to log into UI and obtain his 'id' (#ID), then you record
your new patchset in this way:

* <code>$ tracker record -o ID</code>

The new patchset will replace the old patchset and the version of 'rev' will
be bumped by 1.

<b>Client configuration</b>

By default the tracker command line client will try to connect to tracker
server running on localhost using 'default' credentials. You might need
to change this by:

$ <code>wget https://raw.github.com/mifo/tracker/master/config/trackerrc.example -O ~/.trackerrc</code>

Then edit the <code>~/.trackerrc</code> file and provide valid credentials / URL.

TODO
---------

* <del>authentication (static YAML file?)</del>
* <del>tracker status</del>
* git hook integration
* mail notification
* others?


Designed workflow:
---------

* 0. Person A: <code>$ git checkout awesome_pathes</code>
* 0. Person A: <code>$ git rebase -i master</code>
* 0. Person A: <code>$ git format-patch -o /tmp/patches master</code>
* 1. Person A: <code>$ git send-email --thread /tmp/patches</code>
* 2. Person A: <code>$ tracker record</code> -> (Sends all patches to the 'tracker' application, they appear as 'NEW'. Each patch is 'identified' by its commit HASH)

* 3. Person B: Review patches on the mailing list, ie. creates a new branch in his local GIT and applies patches, then Person runs on his local machine in the GIT repo on local branch he created:

<code>$ tracker ack</code>
('tracker' will set all patch hashes in application to ACK)

<code>$ tracker nack</code>
('tracker' will set all patch hashes in application to NACK)

<code>$ tracker [ack|nack] hash</code>
('tracker' will ACK/NACK just specified hash in application)

* 4. Person A: <code>$ git checkout awesome_patches</code>
* 5. Person A: <code>$ tracker status</code>

This should print status of review for each commit, like:

<pre>
  [ ACK ] 2ad28717 Commit Message 1
  [ NCK ] 2fb0cbb0 Commit Message 2
  [ NEW ] 34fb7b78 Commit Message 3
</pre>

* 5. Person A: <code>$ git push</code> -> (Pushes ACK'ed patches).
* 6. Person A: <code>$ tracker pushed [patches]</code> -> (Notifies tracker that the patches were pushed, ie. set status of patches to PUSH)
* 7. Person A: Buy beer to Person B ;-)
