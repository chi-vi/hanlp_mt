# DRT - Dependency Relation Tags

Bộ nhãn tối giản dùng cho **dep-dict** để tra nghĩa từ theo cặp từ phụ thuộc.

> [!NOTE]
> DRT chỉ dùng cho **dictionary lookup**. Các quy luật ngữ pháp (đảo vị trí, BA, BEI)
> sử dụng trực tiếp deprel gốc trong module `Rules::DeprelRules`.

## Tagset

| DRT | Tên | Deprel gốc | Head → Child | Ví dụ |
|-----|-----|------------|--------------|-------|
| **OBJ** | Tân ngữ | `dobj`, `range`, `attr` | V → N | 吃**饭**, 睡**觉** |
| **RES** | Bổ ngữ KQ | `rcomp` | V → V/A | 看**完**, 吃**饱** |
| **NMOD** | Định ngữ | `nn`, `amod`, `assmod`, `rcmod` | M → N | 服务**中心** |
| **CLF** | Lượng từ | `clf`, `nummod`, `ordmod` | CLF → N | 一**只**猫 |
| **ADV** | Trạng ngữ | `advmod`, `tmod`, `dvpmod`, `mmod` | ADV → V | **先**送上 |
| **PREP** | Giới từ | `prep`, `pobj`, `lobj`, `pccomp`, `loc` | P → N/V | **在**实践中 |
| **BEI** | Thể bị động | `pass`, `nsubjpass` | 被 → V | **被**打/**被**表扬 |
| **OTH** | Ngoại lệ | `ccomp`, `xcomp`, `comod`, `vmod`, `prtmod`, `det` | * → * | Các trường hợp đặc biệt |

**Tổng: 8 tags**

---

## Ghi chú về RES

Chỉ dùng RES khi **bổ ngữ kết quả đổi nghĩa** theo động từ:

```yaml
# ✅ Cần RES - nghĩa thay đổi
["完", "看", "RES", "xong", null]   # 看完 = xem xong
["完", "吃", "RES", "hết", null]    # 吃完 = ăn hết
["饱", "吃", "RES", "no", null]     # 吃饱 = ăn no
["光", "用", "RES", "hết", null]    # 用光 = dùng hết

# ❌ Không cần RES - nghĩa cố định
来/去/上/下/进/出  # Xu hướng - luôn = ra/vào/lên/xuống
极了/得很          # Mức độ - luôn = cực kỳ/lắm
一遍/一趟          # Động lượng - nghĩa theo classifier
```

---

## Ánh xạ Deprel → DRT

```crystal
def deprel_to_drt(deprel : String) : String
  case deprel
  when "dobj", "range", "attr"     then "OBJ"
  when "rcomp"                     then "RES"
  when "nn", "amod", "assmod", "rcmod" then "NMOD"
  when "clf", "nummod", "ordmod"   then "CLF"
  when "advmod", "tmod", "dvpmod", "dvpm", "mmod" then "ADV"
  when "prep", "pobj", "lobj", "pccomp", "loc" then "PREP"
  when "pass", "nsubjpass"         then "BEI"
  else "OTH"  # Fallback cho tất cả trường hợp khác
  end
end
```

---

## Quy trình tra cứu

```
1. Parse dependency tree
2. Với mỗi cặp (child, parent, deprel):
   a. Map deprel → DRT
   b. Nếu DRT != nil:
      - Tra dep-dict: [child, parent, DRT]
      - Nếu có → áp dụng nghĩa mới
3. Fallback: tra pos-dict (UTT)
4. Không tìm thấy → Hán-Việt / OOV handler
```
