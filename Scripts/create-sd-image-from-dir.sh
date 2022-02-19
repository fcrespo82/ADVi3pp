#!/usr/bin/env zsh
: '
Create a microSD disk image from a source directory.
'

# if [[ "$OSTYPE" != "darwin"* ]]; then echo "Work only on macOS, sorry" ; exit 1; fi
if [[ $# -ne 5 ]] ; then echo "Invalid number of arguments" ; exit 1; fi

version=$1
folder=$2
label=$3
imgname=$4
compress=$5

scripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ret=$?; if [[ $ret != 0 ]]; then exit $ret; fi

dgusroot="$( cd "${scripts}/../LCD-Panel/${folder}" && pwd )"
ret=$?; if [[ $ret != 0 ]]; then exit $ret; fi

mkdir -p "${scripts}/../../../releases/v${version}"
ret=$?; if [[ $ret != 0 ]]; then exit $ret; fi

release="$( cd "${scripts}/../../../releases/v${version}" && pwd )"
ret=$?; if [[ $ret != 0 ]]; then exit $ret; fi

img="${release}/${imgname}-${version}.img"

echo "Create microSD image..."
[[ "$OSTYPE" == "darwin"* ]] && BS="1m"
[[ "$OSTYPE" == "linux"* ]] && BS="1M"
dd if=/dev/zero bs=$BS count=260 of="${img}"

echo "Format as FAT32 8 sectors per cluster..."
mkfs.fat -F 32 -n "${label}" -s 8 -v "${img}"

echo "Mount the SD image..."
if [[ "$OSTYPE" == "darwin"* ]] {
  mount=$( sudo hdiutil attach -readwrite -imagekey diskimage-class=CRawDiskImage "${img}" | awk '{print $2}' )
} elif [[ "$OSTYPE" == "linux"* ]] {
  mount=/tmp/advi3-lcd
  mkdir -p "${mount}"
  sudo mount -t vfat -o user,uid=$(id -u) "${img}" "${mount}"
  ret=$?; if [[ $ret != 0 ]]; then mount=""; fi
}
if [[ "${mount}" == "" ]]; then echo "Mounting failed" ; exit 1; fi

echo "Copy files..."
mkdir -p "${mount}/DWIN_SET/"
cp -R -v "${dgusroot}/DWIN_SET/"* "${mount}/DWIN_SET/"

echo "Clean the files..."
find "${mount}" -name '.DS_Store' -delete
find "${mount}" -name '._*' -type f -delete

echo "Detach the SD image..."
if [[ "$OSTYPE" == "darwin"* ]] {
  sudo hdiutil detach "${mount}"
} elif [[ "$OSTYPE" == "linux"* ]] {
  sudo umount "${mount}"
  rm -rf "${mount}"
}

echo "Compress the SD image..."
zip -j "${img}.zip" "${img}"
rm "${img}"

if [[ "${compress}" = "1" ]]; then
  echo "Compress the images in ${dgusroot} into a zip file..."
  pushd "${dgusroot}" >/dev/null || exit 1
  zip -r -x@"${scripts}/excludes.txt" "${release}/${imgname}-${version}.zip" -- *
  popd >/dev/null || exit 1
fi
