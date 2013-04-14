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
