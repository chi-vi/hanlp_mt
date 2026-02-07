# DRT - Dependency Relation Tags

Bộ nhãn tối giản dùng cho **dep-dict** để tra nghĩa từ theo cặp từ phụ thuộc.

> [!NOTE]
> DRT chỉ dùng cho **dictionary lookup**. Các quy luật ngữ pháp (đảo vị trí, BA, BEI)
> sử dụng trực tiếp deprel gốc trong module `Rules::DeprelRules`.

## Tagset

| DRT | Tên | Bias | Deprel gốc | Ví dụ |
|-----|-----|------|------------|-------|
| **RES** | Bổ ngữ KQ | 1 | `rcomp`, `ccomp`, `xcomp` | 看**完**, 打**死** |
| **OBJ** | Tân ngữ | 2 | `dobj`, `range`, `attr`, `ba`, `nsubjpass` | 打**电话**, 把**人**打 |
| **AGT** | Chủ ngữ | 3 | `nsubj`, `top`, `xsubj`, `csubj` | **水**开了, **梅花**盛开 |
| **PREP** | Giới từ | 4 | `prep`, `pobj`, `lobj`, `pccomp`, `loc`, `lccomp`, `plmod` | **在**实践中 |
| **ADV** | Trạng ngữ | 5 | `advmod`, `tmod`, `dvpmod`, `dvpm`, `mmod`, `neg` | **先**送上 |
| **NMOD** | Định ngữ | 6 | `nn`, `amod`, `assmod`, `rcmod` | 服务**中心** |
| **CLF** | Lượng từ | 7 | `clf`, `nummod`, `ordmod`, `det` | 一**只**猫 |
| **BEI** | Bị động | 8 | `pass` | **被**打 |
| **OTH** | Ngoại lệ | 9 | `comod`, `vmod`, `prtmod`, `conj`, `cc`, `cop`, `etc`, `asp`, `punct`, `dep` | Fallback |

**Tổng: 9 tags**

---

## Độ ưu tiên (Bias)

Khi một từ tham gia vào **nhiều quan hệ phụ thuộc**, tra cứu theo thứ tự bias từ thấp → cao:

```
我把人打死了
│
├─ 打 →rcomp→ 死 (RES, bias=1) ✓ Tra trước: (死, 打, RES) → "chết"
├─ 打 →ba→ 人 (OBJ, bias=2)   ✓ Tra sau: (打, 人, OBJ) → "đánh"
└─ 打 ←nsubj← 我 (AGT, bias=3) ✓ Tra cuối nếu cần
```

### Lý do thứ tự:

| Bias | DRT | Lý do |
|------|-----|-------|
| 1 | **RES** | Thay đổi nghĩa động từ **hoàn toàn** (打死 ≠ 打, 看完 ≠ 看) |
| 2 | **OBJ** | Phân biệt nghĩa động từ **theo tân ngữ** (打电话 vs 打毛衣 vs 打人) |
| 3 | **AGT** | Đôi khi thay đổi nghĩa (水开 = sôi vs 开水 = mở nước) |
| 4 | **PREP** | Ngữ cảnh công cụ/địa điểm (用刀 = bằng dao) |
| 5 | **ADV** | Thường chỉ bổ sung mức độ/cách thức |
| 6 | **NMOD** | Định ngữ ít ảnh hưởng nghĩa gốc |
| 7 | **CLF** | Lượng từ có nghĩa tương đối cố định |
| 8 | **BEI** | Chỉ thêm bị/được, không đổi nghĩa gốc |
| 9 | **OTH** | Fallback cuối cùng |

---

## Ghi chú

### AGT (Chủ ngữ)
Dùng khi cần phân biệt nghĩa động từ theo chủ ngữ:
```yaml
# Ví dụ: 开 có nghĩa khác nhau tùy vai trò của 水
["开", "水", "AGT", "sôi", null]   # 水开了 = Nước sôi
["开", "水", "OBJ", "mở", null]    # 开水龙头 = Mở vòi nước
```

### OBJ (Tân ngữ)
Gộp cả `nsubjpass` và `ba` vì:
- **nsubjpass**: Chủ ngữ bị động thực chất là đối tượng chịu tác động
- **ba**: Cấu trúc 把 đưa tân ngữ lên trước động từ

```yaml
# Cùng tra cặp (打, 人, OBJ) cho cả 3 câu:
# 我打人 (dobj) / 人被打 (nsubjpass) / 我把人打了 (ba)
["打", "人", "OBJ", "đánh", null]
```

### RES (Bổ ngữ kết quả)
Chỉ dùng khi **bổ ngữ đổi nghĩa** theo động từ:

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

### BEI (Bị động)
Chỉ dùng cho marker `被`, không gộp `nsubjpass`:
- `被` cần thêm "bị/được" trong tiếng Việt
- `nsubjpass` đã gộp vào OBJ để tra nghĩa động từ

---

## Ánh xạ Deprel → DRT

```crystal
def deprel_to_drt(deprel : String) : String
  case deprel
  # Chủ ngữ / Tác thể
  when "nsubj", "top", "xsubj", "csubj" then "AGT"
  # Tân ngữ / Thụ thể
  when "dobj", "range", "attr", "ba", "nsubjpass" then "OBJ"
  # Bổ ngữ kết quả
  when "rcomp", "ccomp", "xcomp" then "RES"
  # Định ngữ danh từ
  when "nn", "amod", "assmod", "rcmod" then "NMOD"
  # Lượng từ
  when "clf", "nummod", "ordmod", "det" then "CLF"
  # Trạng ngữ
  when "advmod", "tmod", "dvpmod", "dvpm", "mmod", "neg" then "ADV"
  # Giới từ / Phương vị
  when "prep", "pobj", "lobj", "pccomp", "loc", "lccomp", "plmod" then "PREP"
  # Bị động marker
  when "pass" then "BEI"
  else "OTH"
  end
end
```

---

## Quy trình tra cứu

```
1. Parse dependency tree
2. Với mỗi cặp (child, parent, deprel):
   a. Map deprel → DRT
   b. Nếu DRT != OTH:
      - Tra dep-dict: [child, parent, DRT]
      - Nếu có → áp dụng nghĩa mới
3. Fallback: tra pos-dict (UTT)
4. Không tìm thấy → Hán-Việt / OOV handler
```
