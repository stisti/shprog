Pitfalls
========

Using Bashisms and Gnuisms
--------------------------

Bash, the Bourne Again shell from the GNU project, is pretty popular these days with Linux everywhere you look. However, there are still a couple of other UNIX flavours hanging around and Bash is not usually installed there. Shell scripts should try to be as operating system independent as possible. The only way to accomplish this is to only use features present in the original Bourne shell, the ``/bin/sh``. This can be tricky because these days most script writers have been brought up on Linux. They are used to using the nifty features of bash and other GNU tools. They are absolutely dumbfounded when they have to make their script run on Solaris or HP-UX for the first time. Here is a list of things I've come across that will fail on non-Linux platforms.

Another pitfall these days is the fact that some distributions no longer make ``/bin/sh`` a symlink to ``/bin/bash``. The popular Ubuntu Linux is one of them. ``/bin/sh`` is actually a very small, POSIX-compatible shell.

Arithmetics
-----------

In bash you can do::

    a=$((5 * 6 + 2))

But in the one true shell the only command that knows arithmetic is expr::

    a=`expr 5 \* 6 + 2`

Use of Tilde to Reference the Home Directory
--------------------------------------------

In bash you can use the tilde (``~``) to refer to your home directory and ``~user`` to refer to a specified user's home directory.

In the one true shell your home directory is \$HOME. Someone else's home directory can only be found by looking it up from ``/etc/passwd``.

::

    awk -F: '$1 == "user" { print $6 }' /etc/passwd

Redirection shortcuts
---------------------

In bash (and csh) you can redirect both standard output and standard error streams to a file with a convenient shorthand.

::

    command >&file

But in the one true shell you have to spell it out in full, do it for both stdout and stderr.

::

    command >file 2>&1


Order of Redirections
---------------------

What is the difference of the following command lines?

::

    command >file 2>&1
    command 2>&1 >file

The first is the one you probably wanted. It reads like this: "Redirect standard output to a file. Then redirect standard error to where standard output is attached." Both streams will be written to the same file.

The second command line reads: "Redirect standard error to where standard output is attached (probably a terminal). Then redirect standard output to a file." The errors will appear on the terminal and output will be written to the file.

There are two things to remember. One, the redirections are processed from left to right. Two, the notation ``2>&1`` does not make stderr to go stdout, instead it attaches stderr to where stdout was attached at this moment. In the second case above, the standard output was still connected to the terminal when the first redirection was being processed.

OK, then how do you send both stdout and stderr to another command?

::

    make 2>&1 | less

This is a special case. Above it was emphasized you first change where stdout goes and only then pipe everything else to stdout. Not here. The reason is you really have 2 commands connected by a pipe. Piping is not the same as redirecting.


Backticks and Command Line Length
---------------------------------

Many programmers know that the maximum length of a command is very limited in MS-DOS. UNIX programmers seem to think they have an infinite command length or at least the length is so long they don't have to worry about it. The prime example is what happens when you put the find command inside backticks.

::

    wc -l `find . -type f`

This works fine as long as the number of files printed by the find is less than the maximum command line length of the operating system. It might work for you when you test it. But does it work for someone using your script? Why not be sure and use xargs?

::

    find . -type f | xargs wc -l

By the way, both of the above will fail miserably if there are filenames with spaces. There is no way to make the first command work properly. The second command can be made to work with minor modifications:

::

    find . -type f | xargs -I xxx wc -l xxx

xargs will read lines from its standard input and run wc -l with xxx replaced with one line, over and over again until all lines from stdin are exhausted. xargs is free to run wc -l with more than one argument, if the replacement of xxx with multiple lines does not exceed the maximum command line length.

How to Refer to All Command Line Arguments?
-------------------------------------------

Often you write a small script to act as a front-end to some other utility. Typically these scripts check invoke some process with all the remaining command line arguments. Some script-writers use the ``$*`` and some ``$@``. Is there a difference? Does it matter? Yes it does.

First of all, both ``$@`` and ``$*`` need to be enclosed in double quotes to work properly (``"$@"`` and ``"$*"``). Unquoted, they behave the same. Let's examine the issue with some examples. First, let's write a script called printargs.sh that only prints it arguments.

::

    #!/bin/sh
    for a; do
            echo "$a"
    done

Then write a script called argtest.sh that tries out the different possibilities.

::

    #!/bin/sh
    echo 'Using $@'
    ./printargs.sh $@
    echo 'Using $*'
    ./printargs.sh $*
    echo 'Using "$@"'
    ./printargs.sh "$@"
    echo 'Using "$*"'
    ./printargs.sh "$*"

Then we execute it and see the following output.

::

    ./argtest.sh "1 2" 3
    Using $@
    1
    2
    3
    Using $*
    1
    2
    3
    Using "$@"
    1 2
    3
    Using "$*"
    1 2 3

As you see, usually you want the behaviour of the ``"$@"``. Anything else will bite you in the backside when someone gives your script an argument that contains spaces.

Lock files
----------

Sometimes you can only have one instance of your script running. Perhaps you are updating some important system files and you must be sure it all works properly, even if two different root users are logged on and invoke your script with no idea another admin is already doing the same thing. Your script must take some kind of lock before starting to do its work and then release the lock when it is done.

A lock could be the existence of a file. But how do you both create a file and fail to create it if it already existed? You have two possibilities: a hard link and a directory. Creation for both of them is an atomic operation that will fail if the thing already exists.

You could do something like this::

    echo $$ > lock.$$
    if ln lock.$$ lockfile; then
        echo "Lock acquired"
    else
        echo "Failed to get the lock"
    fi

But what if an instance of that script died while holding the lock? You must set up a trap statement that will remove the lockfile when something unexpected happens.

::

    trap "rm -f lock.$$ lockfile" EXIT SIGHUP SIGTERM SIGINT
    echo $$ > lock.$$
    if ln lock.$$ lockfile; then
        echo "Lock acquired"
    else
        echo "Failed to get the lock"
    fi

Something bad might still happen. Your script is killed with ``kill -9`` or the power fails. Whatever. The fact of the matter is that when your script runs, lockfile exists and it never gets the lock. That's why the lockfile is a link to a file that has the PID of the process that created it. We can simply check if that process exists.

::

    echo $$ > lock.$$
    trap "rm -f lock.$$ lockfile" EXIT SIGHUP SIGTERM SIGINT
    if ln lock.$$ lockfile; then
        echo "Lock acquired"
    else
        lockholder=`cat lockfile`
        if kill -0 $lockholder; then
            echo "Failed to get the lock, lock is held by $lockholder"
        else
            rm -f lockfile
            echo "Lock was held by $lockholder (died), try again now"
        fi
    fi

Something like that. Or you could have a loop trying the hard link over and over as long as it takes for it to succeed.

But what if the process-id read from the lockfile is an existing process, it's just not an instance of your script? Now things get tricky. In general, there might not be a portable solution, but if you can forget portability, there are things you can do.

If you can check when a process was launched, you can compare it against the modification time of lockfile. If they are reasonably close, then the creator of the lockfile is probably still alive.

Handling lock files correctly is a difficult problem that few programs get right. A better way would be to make lockfile be a unix domain socket instead of a file. Then checking if the lock holder was still alive would be a simple matter of connecting to the socket. If the connection was refused, there was no-one home. If the connection was established, you could talk to the other end and ask if the lock holder was still ok. Possibly the lock holder could even reply with an estimate of how long it is going to hold the lock. But, if the connection was refused, you would have to remove the stale socket and try bind a new one.

Unix domain sockes, unfortunately, are not easily manipulated from a shell script. You could make a Perl script that created the socket and responded to anyone connecting to it. But then you would need to run that Perl script in the background, executing in parallel with your script. Which you can do, just see below.

Another possibility would be to use advisory file locks (flock/fcntl/lockf) but again, they are not accessible to shell scripts, but they are to Perl. The advantage of file locks is they are unlocked by the operating system if the process holding the lock should die.

You could use a helper like this::

    #!/usr/bin/perl -w
    # Lockfile helper by Sami Tikka 2007
    #
    # Usage from a shell script:
    # lockholder=`lockfile PATH_TO_LOCKFILE` || exit 1
    # echo "Lock acquired"
    # echo "Doing my thing"
    # echo "Releasing lock"
    # kill $lockholder
    #
    use strict;
    use Fcntl ':flock';

    die "USAGE: lockfile PATH_TO_LOCKFILE" if $#ARGV != 0;

    my $lockfile = shift @ARGV;
    my $LOCK;
    my $signaled = 0;
    $SIG{'INT'}  = sub { $signaled++ };
    $SIG{'TERM'} = sub { $signaled++ };

    open($LOCK, '>', $lockfile) or die "Cannot open $lockfile: $!";
    flock($LOCK, LOCK_EX|LOCK_NB) or exit 1;
    my $lockholder = fork();
    # Parent prints the PID of child who will hang around and hold the lock
    if ($lockholder > 0) {
        print "$lockholder\n";
        exit 0;
    }
    sleep;
    flock($LOCK, LOCK_UN);
    close($LOCK);
    unlink($lockfile);
    exit 0;

The shell script would acquire the lock by running the Perl script, capturing Perl's standard output and verifying its exit code. If the exit code was nonzero, lock was not acquired. If the exit code was zero, standard output will contain the id of the process that needs to be killed to release the lock.

Doing more than one thing at the same time
------------------------------------------

Normally your script only has one thread of execution, it runs the commands one at a time, or one pipeline at a time. Sometimes you need to do more. For example, you might want to run a script which takes a long time and you want to make sure it does not take more than 3 hours.


Assumption is the mother of all...
----------------------------------

Locale and language
~~~~~~~~~~~~~~~~~~~

These days users of modern Unix systems expect the operating system and applications to be localized. This is a benefit to the end-users who might not be fluent in English, but it is bad for the script writer: Applications might produce output which is completely different from what you expect. Also, you may get bug reports from your users with error messages in japanese or some other language you don't know that well.

The careful scripter will put these lines somewhere at the beginning of their script::

    LANG=C
    export LANG

This will make everything executed after it use the C locale, where programs produce standardized output and error messages, in English.

If your script needs to produce localized output, you can capture the user's locale settings before replacing them with your own::

    user_locale=`locale`

If needed, you can restore them with::

    eval $user_locale

PATH lookup
~~~~~~~~~~~

If your script needs ``/usr/bin/X11`` to be in PATH, do not assume it is there. If you need something to be in PATH, add it there.

UMASK and default permissions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When your script creates files, even temporary files, you might want to be explicit with the permissions they are created with. If your script deals with user's data and the point of the script is not to share the data, set umask to 0066. It is better to create files with tight permissions and then relax for those few files that need relaxing. If you create files that are world-readable and then remove the world-readability after creation, there will be a window of time during which the file will be readable by everyone and sometimes that is all the attacker needs.

Echo does not support -n or -e
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sometimes you want to be fancy in your printouts, you want to prevent echo from printing the newline at the end of the line or something else: you want to call echo with the -n or -e option. Couple of points:

First, when you call echo, it might be a shell built-in command or it might be ``/bin/echo``. They might behave differently.

Second, the echo you call might not support -n or -e or either.

It is best to use echo without options and when you need better control for printout, use printf.
