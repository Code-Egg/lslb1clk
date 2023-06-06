# lslb1clk
[<img src="https://img.shields.io/badge/Made%20with-BASH-orange.svg">](https://en.wikipedia.org/wiki/Bash_(Unix_shell)) 

Description
--------
This script is design for application quick install and testing porpuse.

lslb1clk is a one-click installation script for LiteSpeed Web ADC Server. Using this script,
you can quickly and easily install LSADC and some example config setup. 

The script come with trial license by default which has 15 days for free. After that, you may want to apply with your license. Or you can apply your serial number with `--license xxxxxxxx`. [Read More](https://litespeedtech.com/products/litespeed-web-adc/webadc-pricing)

# How to use
---------

## Install Pre-Requisites
For CentOS/RHEL Based Systems
```bash
yum install git -y; git clone https://github.com/Code-Egg/lslb1clk.git
```

For Debian/Ubuntu Based Systems
```bash
apt install git -y; git clone https://github.com/Code-Egg/lslb1clk.git
```

## Install
### Pure LSADC
``` bash
lslb1clk/lslb1clk.sh
```
### Specified serial number 
``` bash
lslb1clk/lslb1clk.sh -L xxxxxxxxxxxxx
```

### Predefined configuration
**Vultr Scaling Example:**
``` bash
lslb1clk/lslb1clk.sh --scaling-vultr
```

## Uninstall
### Uninstall LSADC
``` bash
lslb1clk/lslb1clk.sh --uninstall
```

# Problems/Suggestions/Feedback/Contribution
Please raise an issue on the repository, or send a PR for contributing. 
