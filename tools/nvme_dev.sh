#!/bin/bash
#
# lspci -d1e3b: -v | grep -e NUMA -e Non-Vol | sed -r -e "s/(.*)\s+Non-Vol.*/\1/g" -e "s/.*NUMA node\s([0-9]+).*/\1/g" 
#

function nvme2busid_full() {
    drv_name=$1
    bdf=$(cat /sys/class/nvme/${drv_name%n*}/address)
    echo ${bdf}
}

function nvme2busid() {
    drv_name=$1
    bdf=$(nvme2busid_full ${drv_name})
    bdf=${bdf##*0000:}
    echo ${bdf}
}

function nvme2busid_spdk() {
    drv_name=$1
    bdf=$(nvme2busid ${drv_name})
    echo ${bdf/:/.}
}

function busid2lspci_vv() {
    bdf=$1
    if [ ! -z "${bdf}" ]
    then
        echo "$(lspci -s ${bdf} -vv)"
    else
        echo ""
    fi 
}

function lspci_vv2numa() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep NUMA | sed -r "s/.*NUMA node:\s+([0-9]+).*/\1/g")
    else
        echo ""
    fi 
}

function busid2numa() {
    bdf=$1
    if [ ! -z "${bdf}" ]
    then
        echo $(lspci -s ${bdf} -v | grep NUMA | sed -r "s/.*NUMA node:\s+([0-9]+).*/\1/g")
    else
        echo ""
    fi 
}

function nvme2numa() {
    drv_name=$1
    bdf=$(nvme2busid ${drv_name})
    if [ ! -z "${bdf}" ]
    then
        echo $(busid2numa ${bdf})
    else
        echo ""
    fi    
}

function lspci_vv2desc() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep "Non-Volatile" | cut -d: -f3-)
    else
        echo ""
    fi 
}

function busid2desc() {
    bdf=$1
    echo $(lspci -s ${bdf} | cut -d: -f3-)
}

function lspci_vv2lnksta() {
    lspci_vv=$1
    if [ ! -z "$(echo ${lspci_vv} | grep '\[virtual\]')" ]
    then
        echo "VF?"
    else
        echo $(echo "${lspci_vv}" | grep LnkSta: | sed -r "s/.*\s+([0-9]+GT).*,.*(x[0-9]+).*/\1+\2/g")
    fi 
}

function busid2lnksta() {
    bdf=$1
    lspci_vv=$(lspci -s ${bdf} -vv)
    if [ ! -z "$(echo ${lspci_vv} | grep '\[virtual\]')" ]
    then
        echo "VF"
    else
        echo $(echo "${lspci_vv}" | grep LnkSta: | sed -r "s/.*\s+([0-9]+GT).*,.*(x[0-9]+).*/\1+\2/g")
    fi
}

function lspci_vv2max_pl_rrq() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep DevCtl: -A2 | grep MaxPayload | sed -r "s/\s+MaxPayload\s+([0-9]+)\s+.*MaxReadReq\s+([0-9]+)\s+.*/\1+\2/g")
    else
        echo ""
    fi 
}

function busid2max_pl_rrq() {
    bdf=$1
    echo $(lspci -s ${bdf} -vv | grep DevCtl: -A2 | grep MaxPayload | sed -r "s/\s+MaxPayload\s+([0-9]+)\s+.*MaxReadReq\s+([0-9]+)\s+.*/\1+\2/g")
}

function lspci_vv2is_phy_dev() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep "\[virtual\]")
    else
        echo ""
    fi 
}

function is_physical_dev() {
    bdf=$1
    phy_slot=$(lspci -s ${bdf} -v | grep "Physical Slot:")
    is_phy_slot=1
    if [ -z "${phy_slot}" ]
    then
        is_phy_slot=0
    fi
    echo ${is_phy_slot}
}

if [ ! -z "`nvme list | grep nvme`" ]
then
    # echo "drive,bdf,numa_node,lnksta,max_pl+rrq,temp,desc"
    print_fmt="%9s%9s%6s%9s%12s%6s  %-s\n"
    printf "${print_fmt}" drive bdf numa lnksta max_pl+rrq temp desc
    for nvme_dev in  `nvme list | sort -V | grep /dev/nvme | cut -d" " -f1`
    do 
        drv=${nvme_dev##*/}
        bdf=$(nvme2busid ${drv})
        if [ ! -z "${bdf}" ]
        then 
            temp=$(nvme smart-log /dev/${drv} | grep temperature | cut -d: -f2)
            lspci_vv="$(lspci -s ${bdf} -vv)"
            numa_node=$(lspci_vv2numa "${lspci_vv}")
            lnksta=$(lspci_vv2lnksta "${lspci_vv}")
            max_pl_rq=$(lspci_vv2max_pl_rrq "${lspci_vv}")
            desc=$(lspci_vv2desc "${lspci_vv}")
            # echo ${drv}, ${bdf}, ${numa_node}, ${lnksta}, ${max_pl_rq}, ${temp}, ${desc}
            printf "${print_fmt}" ${drv} ${bdf} ${numa_node} ${lnksta} ${max_pl_rq} "${temp}" "${desc}"
        else
            echo "${drv},info not availble"
        fi
    done
else
    header="bdf,numa_node,lnksta,max_pl+rrq,desc"
    # header=(bdf numa lnksta max_pl+rrq desc)
    print_fmt="%9s%6s%9s%12s  %-s\n"
    printf "${print_fmt}" bdf numa lnksta max_pl+rrq desc
    for pcie_dev in  `lspci | grep "Non-Volatile memory controller" | cut -d" " -f1`
    do
        bdf=${pcie_dev}
        lspci_vv="$(lspci -s ${bdf} -vv)"
        numa_node=$(lspci_vv2numa "${lspci_vv}")
        lnksta=$(lspci_vv2lnksta "${lspci_vv}")
        max_pl_rq=$(lspci_vv2max_pl_rrq "${lspci_vv}")
        desc=$(lspci_vv2desc "${lspci_vv}")
        if [ ! -z "${bdf}" ]
        then
            # echo ${bdf},${numa_node},${lnksta},${max_pl_rq},${desc}
            printf "${print_fmt}" ${bdf} ${numa_node} ${lnksta} ${max_pl_rq} "${desc}"
        fi
    done
fi