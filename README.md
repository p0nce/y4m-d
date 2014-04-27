## What's this?

y4m-d is a tiny library to load/save Y4M video files.
Y4M files are the simplest uncompressed video files that also contain meta-data 
(width, height, chroma subsampling, etc...) which makes a better solution than .yuv files.

## Licenses

See UNLICENSE.txt


## Usage


```d

import y4md;

void main(string[] args)
{
   auto input = new Y4MReader("input-file.y4m");

    writefln("Input: %s %sx%s %sfps", inputFile, input.width, input.height,
             cast(double)(input.framerate.num) / (input.framerate.denom));

    ubyte[] frameBytes;
    while ( (frameBytes = input.nextFrame()) !is null)
    {
        // Do something with frame data in frameBytes[]
    }
}

```
