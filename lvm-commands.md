# LVM Usefull Commands

## List actual phisical volumes

```
sudo pvs
```

## List actual volume groups

```
sudo vgs
```

## List actual logical volumes

```
sudo lvs
```

## Get more information on volume groups

```
sudo vgdisplay
```

## Create a snapshot volume

```
sudo lvcreate --size 1G --snapshot --name datas-snap /dev/lvm-vg/datas
```

## Remove a volume

```
sudo lvremove /dev/lvm-vg/datas
```

