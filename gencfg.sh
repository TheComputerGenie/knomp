#!/bin/bash
# Put the address to mine to here
walletaddress=

#Change to path of komodo-cli here
komodoexec=$HOME/komodo/src/komodo-cli

# Any coins you would like to skip go here
#THC & GLEEC are PoS
declare -a skip=("THC" "GLEEC")

# Stratum port to start with
stratumport=3030

cli="komodo-cli"
coinsdir=./coins
poolconfigdir=./pool_configs
coinstpl=coins.template
pooltpl=poolconfigs.template
ufwenablefile=stratufwenable
ufwdisablefile=stratufwdisable

cointemplate=$(<$coinstpl)
pooltemplate=$(<$pooltpl)

mkdir -p $coinsdir
mkdir -p $poolconfigdir

#clean old up
if [ -f $ufwenablefile ]; then
    rm $ufwenablefile
fi
if [ -f $ufwdisablefile ]; then
    rm $ufwdisablefile
fi

if [[ -z $1 ]]; then
  specificchain=0
else
  specificchain=$1
fi

listassetchains () {
  if [[ $specificchain = "0" ]]; then
    $HOME/komodo/src/listassetchains
  else
    echo $specificchain
  fi
}

listassetchains | while read chain; do
  if [[ " ${skip[@]} " =$HOME " ${chain} " ]]; then
    pointless=0
  else
    echo  "[$chain] Generating config files"
    getinfo=$(${cli} -ac_name=$chain getinfo 2>/dev/null)
    outcome=$(echo $?)

    if [[ $outcome != 0 ]]; then
       echo "[$chain] Daemon is not running skipped."
       continue
    fi

    string=$(printf '%08x\n' $(jq '.magic' <<<"${getinfo}"))
    magic=${string: -8}
    magicrev=$(echo ${magic:6:2}${magic:4:2}${magic:2:2}${magic:0:2})

    p2pport=$(jq '.p2pport' <<<"${getinfo}")
    thisconf=$(<$HOME/.komodo/$chain/$chain.conf)

        rpcuser=$(grep -Po "rpcuser=(\S*)" | sed 's/rpcuser=//' <<<"${thisconf}")
        rpcpass=$(grep -Po "rpcpassword=(\S*)" | sed 's/rpcpassword=//' <<<"${thisconf}")
        rpcport=$(grep -Po "rpcport=(\S*)" | sed 's/rpcport=//' <<<"${thisconf}")

        echo "$cointemplate" | sed "s/COINNAMEVAR/$chain/" | sed "s/MAGICREVVAR/$magicrev/" > $coinsdir/$chain.json
        echo "$pooltemplate" | sed "s/P2PPORTVAR/$p2pport/" | sed "s/COINNAMEVAR/$chain/" | sed "s/WALLETADDRVAR/$walletaddress/" | sed "s/STRATUMPORTVAR/$stratumport/" | sed "s/RPCPORTVAR/$rpcport/" | sed "s/RPCUSERVAR/$rpcuser/" | sed "s/RPCPASSVAR/$rpcpass/" > $poolconfigdir/$chain.json

        echo "sudo ufw allow $stratumport comment 'Stratum $chain'" >> $ufwenablefile
        echo "sudo ufw delete allow $stratumport" >> $ufwdisablefile

        let "stratumport = $stratumport + 100"
    fi
done

chmod +x $ufwenablefile
chmod +x $ufwdisablefile
