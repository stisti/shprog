Elements of Style
=================

True and False Reversed
-----------------------

Every UNIX process has an exit value which is made available to the parent process. A long-standing convention states that the exit value zero indicates success and any other value some kind of error.

Since every command used in a shell script is a UNIX process, the same applies: zero is true and anything else is false. This runs contrary to the established convention from the C language where zero is false and anything else is true. However, if one manages to unlearn what has been taught in the C classes, life becomes much easier for the script writer.

Let's look at some examples. The script below is what a novice shell-scripter usually writes::

    grep pattern file
    ret=$?
    if [ $ret -eq 0 ]; then
        echo 'Found it!'
    else
        echo 'Not found'
    fi

Compare that with the script from a more seasoned professional::

    if grep pattern file; then
        echo 'Found it!'
    else
        echo 'Not found'
    fi

The pro might even pull it off using a one-liner::

    grep pattern file && echo 'Found it!' || echo 'Not found'


Commands Usually Have a Useful Exit Value
-----------------------------------------

It is common for the novice scripter to check for the output of the grep command. Look at the code sample below::

    isdriverloaded() {
        addeddriver=`modinfo | grep fsvpn`
        if [ -z "$addeddriver" ]; then
            return 0
        fi
        return 1
    }

What we really want to know is if grep found any lines matching the pattern. The grep command has a useful exit value, it returns zero (success) if one or more matches were found. So, instead of storing the (possibly large) output from grep, which we really don't care about, we should be checking grep's exit value. Note that the script writer has also committed the sin described in the previous section: failing to grasp that zero is true and 1 is false. A better version of the function would read::

    isdriverloaded() {
        modinfo | grep fsvpn >/dev/null
    }

To learn why it works, look at the explanation in the next section.

The tty command prints the name of the terminal device the process is attached to, or "not a tty" if there is no terminal. Again, the novice would capture the output of the tty command and check that somehow::

    if [ "`tty`" = "not a tty" ]; then
        echo "a hard-to-read way of checking for tty"
    fi

or::

    if tty | grep "not a tty" >/dev/null; then
        echo "just as bad"
    fi

We are depending on the exact output of that command. In the former example above, we capture the command output, then invoke the test command to compare it. (The test command is also known as [, the opening bracket.) In the latter example, we also invoke two processes, only this time they run at the same time.

A better way would be to notice the tty command has an exit code and using it makes the script very readable and efficient and it would work even when the user's locale settings make tty talk in japanese or tagalog::

    if ! tty >/dev/null; then
        echo "Look ma! No tty!"
    fi


Invisible Exit Value
--------------------

Shell functions always return a value, even when there is no return statement anywhere in the function. In such a case the exit value will be the exit value of the last process executed in the shell function. Consider the following function::

    stop() {
        [ -x /etc/init.d/service ] && /etc/init.d/service stop
    }

If you are checking the exit value from this function, you might be surprised. The exit value may not be the exit value of the ``/etc/init.d/service``. If the file ``/etc/init.d/service`` was not executable or did not exist at all, the function would return a value indicating failure. You might be well advised to add an explicit return 0 to the end of the function.

Of course, sometimes this behaviour is exactly what you want::

    isrunning() {
        [ -e /var/run/daemon.pid ] && \
        kill -0 `cat /var/run/daemon.pid` 2>/dev/null
    }


Use true and false Instead of 1 and 0
-------------------------------------

When you want to use a variable like a Boolean, some people do it like this::

    upgrade=1
    if [ $upgrade -eq 1 ]; then
            do_upgrade
    fi

The code is much more readable when written like this::

    upgrade=true
    if $upgrade; then
            do_upgrade
    fi

This is possible because there are commands true and false. true is a real command that lives in ``/usr/bin`` or possibly in ``/bin``. When you execute true, it does nothing except exits with code 0, which means success.

Similarly, there is the command false, which does nothing and exits with code 1 meaning failure.

Quoting For Fun and Profit
--------------------------

Quoting is simple, at least in principle. There are just two types of quotes: single quotes (``''``) and double quotes (``""``). Shell variables are expanded inside double quotes. Nothing is expanded inside single quotes. Any quotes disable filename expansion. Regarding filenames, it is usually a good practice to enclose variables that may contain filenames into double quotes. You'll never know when you encounter a filename with a space in it. Leave the filename without double quotes only when you have a filename with wildcard characters in it that you want the shell to expand.

Another difficult area is nested quoting. This kind of situation can arise for example when passing shell variables into an awk or perl script. See this script that prints out the login shell of a user.

::

    #!/bin/sh
    awk -F: '$1 == "'"$1"'" { print $7 }' /etc/passwd

The first single quote is interpreted by the shell, which means the next double quote is passed to awk as is. The second ``$1`` is found quoted in double quotes, so the shell replaces it with the first command line argument. The double quotes are needed just in case the ``$1`` contains spaces. Then the single quotes protect the rest of the awk script from expansion. The script which is seen by the awk interpreter is (assuming 'ftp' was the first argument)::

    $1 == "ftp" { print $7 }

Sometimes splitting quotes could become overwhelming, especially if the text you want to splice in contains quotes. Then you might want to use a mechanism built into awk precisely for this purpose, the ``-v`` option::

    awk -F: -v user=root \
    '$1 == user { print "login shell for", user, "is", $7 }' /etc/passwd

The ``-v`` option originated from GNU version of awk and has since spread into other awk implementations, just be aware it might not be everywhere.

Another tricky case of quoting arises from the use of backticks. You may want to store a file name into a shell variable. The file name is produced by running a command and the file name may contain whitespace. How should it be quoted to be safe? A common approach is::

    docfile="`find $dir -name \*.doc`"

Hmm... but what if the variable ``$dir`` could contain whitespace? Better quote that too. The result would be::

    docfile="`find "$dir" -name \*.doc`"

And now you have quotes within quotes. Shell does not get confused by the nested quotes because the inner quotes are inside the backticks, so they really belong to a separate subshell invocation. But the human reader could well get confused (not to mention some text editors with syntax coloring.)

It turns out the outer quotes are actually not needed. Even though you need quotes in a situation like this::

    docfile="/Users/simon/Documents/Meeting minutes/Meeting with marketing.doc"

You do not need the quotes when the path name is produced by backticks.

::

    docfile=`find "$dir" -name \*.doc`



Useless Use of Cat
------------------

Almost all commands are able to read files specified on their command line. Even so, one sees a lot of pipes like these::

    cat somefile | grep somepattern | ...

This is the basic form of *useless use of cat* syndrome. The ``cat`` command is not needed because ``grep`` can also read files, not just standard input. So the above script should really be written::

    grep somepattern somefile | ...

This has several benefits:

* Omit one useless process, so the pipeline starts faster.
* When ``grep`` has direct access to its data file (or files), it can use memory
  mapping or take other shortcuts that remove the need to read every byte of the file. If reading from standard input, every byte has to be read, otherwise grep cannot access following bytes.
* Reading from files is generally faster than reading from a pipe. Pipes
  are actually nothing more than a buffer in the kernel and the size of the buffer is usually 4 kilobytes. When reading from disk, it is possible to use larger buffer sizes to minimize the number of context switches needed to read the file.

For those commands that do *not* support reading from files, the shell supports redirection of standard input, making it unnecessary to use ``cat`` to feed the pipeline: Instead of::

    cat file | tr 'A-Z' 'a-z' | ...

one should use::

    tr 'A-Z' 'a-z' < file | ...

There is yet another form of useless use of cat one commonly sees: cat as the feeder of a while loop.

::

    cat file | while read line; do
        # do something to $line
    done

This can be written more efficiently like this::

    while read line; do
        # do something to $line
    done < file

Granted, if the body of the while loop is long, moving the file that is being read to the end of the loop does make it harder to understand what exactly is being read. In such cases using a ``cat`` could be used to help the reader of the script. When the loop is short, the extra ``cat`` should be removed.

Another case where ``cat`` is allowed is when it is being used to concatenate files together. E.g. if you need to process several files in a while loop, you have to use ``cat``::

    cat file1 file2 file3 | while read line; do
        # do something to $line
    done
