_HALT()
{
   shutdown -h now
}

_ERROR()
{
   echo -e "${red_}FATAL ERROR IN HD.${end_}"
   _HALT
   exit
}

_CLEAR() # Limpando e desmonstando
{
    umount "$verify_device" &>/dev/null # Desmontando pendrive.
    rm -r "$directory_mount"
    return 0
}

_CHECK() # Checar se as hash batem
{
    # Abrindo arquivo em pendrive.
    . "${directory_mount}/.${PRG}/${KEY_PC}"
    # Pegando hash atual do pendrive
    local conf_hash_pendrive=$(sha512sum <<<"$PENDRIVE_UUID" | cut -d ' ' -f 1)
    # # Pegando hash atual do PC
    local conf_hash_pc=$(sha512sum <<<"$PC_UUID" | cut -d ' ' -f 1)
    if [ "$conf_hash_pendrive" = "$HASH_PENDRIVE" ] && [ "$conf_hash_pc" = "$HASH_PC" ]; then
        echo -e "${cyan_}OK.${end_}"
        _CLEAR
    else
        _HALT
    fi
}
