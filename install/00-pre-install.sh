echo
echo "Available disk devices:"
echo "-----------------------"
lsblk -dn -o NAME,MODEL,SIZE,TYPE | awk '$4=="disk" { printf("/dev/%-8s  %-20s  %6s\n",$1,$2,$3) }'
echo "-----------------------"
echo
