# UTT - Unified Translation Tagset

Bộ nhãn tối giản dùng cho **pos-dict** để tra nghĩa từ.

---

## Tagset

| UTT | Tên gọi | Mapping (Nguồn gốc) | Giải thích & Logic xử lý |
|-----|---------|---------------------|--------------------------|
| **N** | Danh từ | POS: `NN`, `NT` / CONST: `NP`, `FRAG` / NER: `PRODUCT`, `EVENT`, `WORK_OF_ART`, `LAW`, `DATE`, `TIME` | Sự vật, khái niệm, thời gian. `NP` dùng tra thuật ngữ cố định. |
| **V** | Động từ | POS: `VV`, `VC`, `VE`, `VCD`, `VCP`, `VNV`, `VPT`, `VRD`, `VSB` / CONST: `VP`, `IP`, `CP` | Động từ thường, "là" (`VC`), "có" (`VE`). `IP`/`CP` cho thành ngữ/câu cố định. |
| **A** | Tính từ | POS: `JJ`, `VA` / CONST: `ADJP`, `DNP`, `UCP` | `VA` dịch là tính từ. `DNP` (cụm "的") thường là định ngữ mô tả. |
| **D** | Trạng từ | POS: `AD` / CONST: `ADVP`, `DVP`, `PP` | `PP` map vào đây vì cụm giới từ đóng vai trò trạng ngữ. |
| **M** | Lượng/Số | POS: `M`, `CD`, `OD` / CONST: `QP`, `CLP` / NER: `PERCENT`, `MONEY`, `QUANTITY`, `CARDINAL`, `ORDINAL` | Số và đơn vị đo lường. |
| **NR** | Tên riêng | POS: `NR` / NER: `PERSON`, `ORG`, `GPE`, `LOCATION`, `FACILITY`, `NORP` | Tên riêng: người, địa danh, tổ chức, cơ sở. Tra nghĩa cố định. |
| **PN** | Đại từ | POS: `PN`, `DT` / CONST: `DP` | `DT` (này/kia/mỗi) có tính chất tương tự đại từ. |
| **I** | Thán từ | POS: `IJ`, `ON`, `SP` / CONST: `INTJ` | Cảm thán, tượng thanh, trợ từ ngữ khí. |
| **F** | Hư từ | POS: `P`, `BA`, `SB`, `LB`, `DEC`, `DEG`, `DER`, `DEV`, `AS`, `MSP`, `LC`, `ETC` / CONST: `LCP` | Giới từ, markers, phương vị từ. Nghĩa phụ thuộc cấu trúc ngữ pháp. |
| **X** | Khác | POS: `CC`, `CS`, `FW`, `URL`, `EM`, `IC`, `NOI`, `PU` / CONST: `LST` | Liên từ, dấu câu, thành phần ngoại lai. |

**Tổng: 10 tags**

---

## Khi nào cần tách tag?

### Từ đa nghĩa - Cần nhiều tags

```yaml
# 会 - khác nghĩa hoàn toàn
会:N: "hội nghị"
会:V: "biết|có thể"

# 对 - nhiều nghĩa
对:N: "cặp|đôi"
对:V: "đối mặt"
对:A: "đúng"
对:F: "với|đối với"

# 和 - conjunction vs preposition
和:X: "và"
和:F: "với"

# 好 - verb vs adj
好:V: "thích"
好:A: "tốt|hay"
```

### Từ đơn nghĩa - Chỉ cần X

```yaml
但是:X: "nhưng"
如果:X: "nếu"
啊:X: "a|à"
```

### Đại từ - Dùng PN

```yaml
我:PN: "tôi"
你:PN: "bạn|anh|em"
这:PN: "này|đây"
```

---

## Ánh xạ POS-CTB → UTT

```crystal
def pos_to_utt(pos : String) : String
  case pos
  when "NN", "NT"                                    then "N"
  when "VV", "VC", "VE"                              then "V"
  when "JJ", "VA"                                    then "A"
  when "AD"                                          then "D"
  when "M", "CD", "OD"                               then "M"
  when "NR"                                          then "NR"
  when "PN", "DT"                                    then "PN"
  when "IJ", "ON", "SP"                              then "I"
  when "P", "DEC", "DEG", "DER", "DEV", "AS", "MSP",
       "LC", "BA", "SB", "LB", "ETC"                 then "F"
  else                                               "X"
  end
end

def ner_to_utt(ner : String) : String
  case ner
  when "PERSON", "ORG", "GPE", "LOCATION",
       "FACILITY", "NORP"                             then "NR"
  when "PRODUCT", "EVENT", "WORK_OF_ART",
       "LAW", "DATE", "TIME"                          then "N"
  when "PERCENT", "MONEY", "QUANTITY",
       "ORDINAL", "CARDINAL"                          then "M"
  else                                                "X"
  end
end

def con_to_utt(con : String) : String
  case con
  when "NP", "FRAG"                                  then "N"
  when "VP", "IP", "CP", "VCD", "VCP", "VNV",
       "VPT", "VRD", "VSB"                           then "V"
  when "ADJP", "DNP", "UCP"                          then "A"
  when "ADVP", "DVP", "PP"                           then "D"
  when "QP", "CLP"                                   then "M"
  when "DP"                                          then "PN"
  when "INTJ"                                        then "I"
  when "LCP"                                         then "F"
  when "LST"                                         then "X"
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
