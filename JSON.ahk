; ╔══════════════════════════════════════════════════════════════════╗
; ║  JSON.ahk — AutoHotkey v2 JSON Library                          ║
; ║  API: thqby/ahk2_lib সামঞ্জস্যপূর্ণ                              ║
; ║                                                                  ║
; ║  ব্যবহার:                                                         ║

; ║                                                                  ║
; ║    obj := JSON.Load(str)      ; JSON স্ট্রিং → AHK Map/Array    ║
; ║    obj := JSON.LoadFile(path) ; ফাইল → AHK Map/Array            ║
; ║    str := JSON.Dump(obj)      ; AHK Object → JSON স্ট্রিং       ║
; ║    str := JSON.Dump(obj, 2)   ; pretty print (2 স্পেস indent)   ║
; ╚══════════════════════════════════════════════════════════════════╝

class JSON {

    static null  := { base: JSON._Null.Prototype }
    static true  := { base: JSON._True.Prototype }
    static false := { base: JSON._False.Prototype }

    class _Null  { 
        __str() {
            return "null"
        }
    }
    class _True  { 
        __str() {
            return "true"
        }
    }
    class _False { 
        __str() {
            return "false"
        }
    }

    ; ──────────────────────────────────────────────────────────────
    ;  JSON.Load — স্ট্রিং পার্স করে
    ; ──────────────────────────────────────────────────────────────
    static Load(text) {
        static WS := Map(" ",1,"`t",1,"`n",1,"`r",1)
        pos := 1
        src := text
        len := StrLen(src)

        SkipWS() {
            while pos <= len && WS.Has(SubStr(src,pos,1))
                pos++
        }

        Ch(n:=0) {
            return SubStr(src, pos+n, 1)
        }

        ParseVal() {
            SkipWS()
            c := Ch()
            if (c = '"') {
                return ParseStr()
            } else if (c = '{') {
                return ParseObj()
            } else if (c = '[') {
                return ParseArr()
            } else if (c = 't') {
                if SubStr(src,pos,4)!="true"  
                    throw Error("bad literal",,"true")
                pos+=4
                return JSON.true
            } else if (c = 'f') {
                if SubStr(src,pos,5)!="false" 
                    throw Error("bad literal",,"false")
                pos+=5
                return JSON.false
            } else if (c = 'n') {
                if SubStr(src,pos,4)!="null"  
                    throw Error("bad literal",,"null")
                pos+=4
                return JSON.null
            } else if (c="-" || (c>="0"&&c<="9")) {
                return ParseNum()
            } else {
                throw Error("Unexpected char: " c " at pos " pos)
            }
        }

        ParseNum() {
            s := pos
            if Ch()="-" pos++
            while pos<=len && (c:=Ch())>="0" && c<="9"
                pos++
            if pos<=len && Ch()="." {
                pos++
                while pos<=len && (c:=Ch())>="0" && c<="9"
                    pos++
            }
            if pos<=len && (Ch()="e"||Ch()="E") {
                pos++
                if (Ch()="+"||Ch()="-") pos++
                while pos<=len && (c:=Ch())>="0" && c<="9"
                    pos++
            }
            return SubStr(src,s,pos-s)+0
        }

        ParseStr() {
            pos++  ; skip "
            out := ""
            loop {
                if pos>len 
                    throw Error("Unterminated string")
                curChar := Ch()
                if curChar='"' {
                    pos++
                    return out
                }
                if curChar="\\" {
                    pos++
                    e := Ch()
                    pos++
                    switch e {
                        case '"': out.='"'
                        case "\\": out.="\\"
                        case '/': out.='/'
                        case 'b': out.=Chr(8)
                        case 'f': out.=Chr(12)
                        case 'n': out.='`n'
                        case 'r': out.='`r'
                        case 't': out.='`t'
                        case 'u':
                            hex:=SubStr(src,pos,4)
                            pos+=4
                            out.=Chr("0x" hex)
                        default: out.=e
                    }
                } else {
                    out.=curChar
                    pos++
                }
            }
        }

        ParseArr() {
            pos++  ; skip [
            arr := []
            SkipWS()
            if Ch()="]" {
                pos++
                return arr
            }
            loop {
                arr.Push(ParseVal())
                SkipWS()
                c := Ch()
                if c="]" {
                    pos++
                    return arr
                }
                if c!="," 
                    throw Error("Expected , or ] at " pos)
                pos++
            }
        }

        ParseObj() {
            pos++  ; skip {
            m := Map()
            m.CaseSense := false
            SkipWS()
            if Ch()="}" {
                pos++
                return m
            }
            loop {
                SkipWS()
                if Ch()!='"' 
                    throw Error("Expected key at " pos)
                k := ParseStr()
                SkipWS()
                if Ch()!=':' 
                    throw Error("Expected : at " pos)
                pos++
                m[k] := ParseVal()
                SkipWS()
                c := Ch()
                if c="}" {
                    pos++
                    return m
                }
                if c!="," 
                    throw Error("Expected , or } at " pos)
                pos++
            }
        }

        result := ParseVal()
        SkipWS()
        if pos<=len
            throw Error("Trailing chars at pos " pos)
        return result
    }

    ; ──────────────────────────────────────────────────────────────
    ;  JSON.LoadFile — ফাইল থেকে লোড
    ; ──────────────────────────────────────────────────────────────
    static LoadFile(path) {
        if !FileExist(path)
            throw Error("ফাইল পাওয়া যায়নি: " path)
        return JSON.Load(FileRead(path, "UTF-8"))
    }

    ; ──────────────────────────────────────────────────────────────
    ;  JSON.Dump — AHK Object → JSON স্ট্রিং
    ;  space: সংখ্যা (indent স্পেস) বা "" (compact)
    ; ──────────────────────────────────────────────────────────────
    static Dump(val, space:="", _depth:=0) {
        sp   := IsNumber(space) ? Integer(space) : 0
        ind  := sp>0 ? "`n" . _J_Repeat(" ", sp * _depth) : ""
        ind1 := sp>0 ? "`n" . _J_Repeat(" ", sp * (_depth+1)) : ""
        sep  := sp>0 ? ": " : ":"

        ; null/true/false সেন্টিনেল
        if Type(val)="Object" {
            if val.base = JSON._Null.Prototype   
                return "null"
            if val.base = JSON._True.Prototype   
                return "true"
            if val.base = JSON._False.Prototype  
                return "false"
        }

        if val is Array {
            if val.Length=0 
                return "[]"
            parts := []
            for v in val
                parts.Push(ind1 . JSON.Dump(v, space, _depth+1))
            return "[" . _J_Join(parts, ",") . ind . "]"
        }

        if val is Map {
            if val.Count=0 
                return "{}"
            parts := []
            for k,v in val
                parts.Push(ind1 . _J_EscStr(String(k)) . sep . JSON.Dump(v, space, _depth+1))
            return "{" . _J_Join(parts, ",") . ind . "}"
        }

        if IsObject(val) {
            parts := []
            for k,v in val.OwnProps()
                parts.Push(ind1 . _J_EscStr(String(k)) . sep . JSON.Dump(v, space, _depth+1))
            if parts.Length=0 
                return "{}"
            return "{" . _J_Join(parts, ",") . ind . "}"
        }

        if val=""  
            return '""'
        if IsNumber(val) 
            return String(val)
        return _J_EscStr(val)
    }

    ; ──────────────────────────────────────────────────────────────
    ;  JSON.DumpFile — ফাইলে লেখা
    ; ──────────────────────────────────────────────────────────────
    static DumpFile(val, path, space:=2) {
        try FileDelete(path)
        FileAppend(JSON.Dump(val, space), path, "UTF-8")
    }
}

; ── প্রাইভেট হেল্পার ────────────────────────────────────────────────
_J_EscStr(s) {
    s := StrReplace(s, "\",  "\\")
    s := StrReplace(s, '"',  '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, Chr(8),  "\b")
    s := StrReplace(s, Chr(12), "\f")
    return '"' s '"'
}

_J_Repeat(str, n) {
    r := ""
    loop n
        r .= str
    return r
}

_J_Join(arr, sep) {
    r := ""
    for i, v in arr {
        if i>1  r .= sep
        r .= v
    }
    return r
}
