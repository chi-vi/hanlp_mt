# UTT - Unified Translation Tagset

Bộ nhãn tối giản dùng cho **pos-dict** để tra nghĩa từ.

---

## Tagset

| UTT | Mô tả | POS-CTB gốc |
|-----|-------|-------------|
| **N** | Danh từ | NN, NT |
| **V** | Động từ | VV, VA |
| **A** | Tính từ | JJ |
| **D** | Trạng từ | AD |
| **P** | Giới từ | P |
| **M** | Lượng từ/Số | M, CD, OD |
| **NR** | Tên riêng | NR |
| **I** | Thán từ/Tượng thanh/Ngữ khí | IJ, ON, SP |
| **F** | Hư từ/Bổ ngữ/Từ đệm | DEC, DEG, DER, DEV, AS, MSP, LC, BA, SB, LB, VC, VE |
| **X** | Khác | PN, CC, CS, DT, FW, URL, EM, ETC, IC, NOI, PU |

**Tổng: 10 tags**

---

## Khi nào cần tách tag?

### Từ đa nghĩa - Cần nhiều tags

```yaml
# 会 - khác nghĩa hoàn toàn
会:N: "hội nghị"
会:V: "biết|có thể"

# 发展 - nominalization
发展:N: "sự phát triển"
发展:V: "phát triển"

# 对 - nhiều nghĩa
对:N: "cặp|đôi"
对:V: "đối mặt"
对:A: "đúng"
对:P: "với|đối với"

# 好 - verb vs adj
好:V: "thích"
好:A: "tốt|hay"
```

### Từ đơn nghĩa - Chỉ cần X

```yaml
# Đại từ
我:X: "tôi"
自己:X: "mình|bản thân"

# Liên từ
和:X: "và"
但是:X: "nhưng"

# Thán từ
啊:X: "a|à"
```

### Hư từ - Dùng F (cho exceptions)

```yaml
# Nếu cần override logic mặc định
的:F: ""      # thường bỏ qua
了:F: "rồi"   # sentence-final
着:F: ""      # aspect, bỏ qua
```

---

## Phân biệt F vs X

| Tag | Loại từ | Mục đích |
|-----|---------|----------|
| **F** | Hư từ có vai trò ngữ pháp | Cho phép override khi grammar rule có ngoại lệ |
| **X** | Từ không cần phân biệt nghĩa | Fallback mặc định cho từ đơn nghĩa |

Ví dụ:
- `所:F` - MSP, có thể cần tra nghĩa trong một số cấu trúc đặc biệt
- `我:X` - Đại từ, luôn là "tôi", không có ngoại lệ

---

## Ánh xạ POS-CTB → UTT

```crystal
def pos_to_utt(pos : String) : String
  case pos
  when "NN", "NT"                                    then "N"
  when "VV", "VA"                                    then "V"
  when "JJ"                                          then "A"
  when "AD"                                          then "D"
  when "P"                                           then "P"
  when "M", "CD", "OD"                               then "M"
  when "NR"                                          then "NR"
  when "IJ", "ON", "SP"                              then "I"
  when "DEC", "DEG", "DER", "DEV", "AS", "MSP",
       "LC", "BA", "SB", "LB", "VC", "VE"            then "F"
  else                                               "X"
  end
end

def ner_to_utt(ner : String) : String
  case ner
  when "PERSON", "NORP", "FACILITY", "ORGANIZATION",
       "GPE", "LOCATION", "PRODUCT", "EVENT",
       "WORK OF ART", "LAW"                          then "NR"
  when "DATE", "TIME"                                then "N"
  when "PERCENT", "MONEY", "QUANTITY",
       "ORDINAL", "CARDINAL"                         then "M"
  else                                               "X"
  end
end

def con_to_utt(con : String) : String
  case con
  when "NP", "NN"                                    then "N"
  when "VP", "VCD", "VCP", "VNV", "VPT", "VRD", "VSB" then "V"
  when "ADJP"                                        then "A"
  when "ADVP"                                        then "D"
  when "PP"                                          then "P"
  when "QP", "CLP"                                   then "M"
  when "INTJ"                                        then "I"
  when "DNP", "DVP", "LCP", "CP", "MSP"              then "F"
  else                                               "X"
  end
end
```

---

## Quy trình tra cứu

```
1. Tra "word:UTT_TAG" → nghĩa theo tag
2. Fallback: tra "word:X" → nghĩa mặc định
3. Không tìm thấy → Hán-Việt / OOV handler
```
