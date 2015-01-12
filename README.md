# Overview
This is a basic script that allows you to upload files to S3 incrementally using the sync feature of [s3cmd](http://s3tools.org/s3cmd). The script also includes built-in logging and other opinionated configuration. The script is designed for syncing large folders with many items and is optimized accordingly.

# Usage
You must first create an s3cmd configuration file by running `s3cmd --configure`. Add your key, secret, and other information to complete setup. When you're finished, an .s3cfg file will be generated in your home directory (the location will vary depending on your OS and distribution). Please include the path to this folder in the script before running it.

# License
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
