# DRT - Dependency Relation Tags
Bộ nhãn dùng cho **dep-dict** để tra nghĩa từ theo cặp từ phụ thuộc.
> [!IMPORTANT]
> Các quan hệ hư từ (BA, BEI, LOC) là yếu tố quyết định cấu trúc câu tiếng Việt,
> cần được xử lý trong module riêng, KHÔNG được bỏ qua.
---
## Bảng Nhãn DRT (18 nhãn)

| Nhóm | DRT Tag | Tương ứng HanLP SD | Mô tả & Logic Xử lý (Action) |
| :---- | :---- | :---- | :---- |
| **Động từ** | **OBJ** | dobj | Tân ngữ thường. Tra từ điển: V + OBJ. |
|  | **SEP** | dobj (Check Dict) | **Liheci (Động từ ly hợp).** Nếu cặp V-N nằm trong danh sách ly hợp → Dịch V (nghĩa gộp), ẩn N. |
|  | **PIV** | ccomp, xcomp | **Câu sai khiến/Kiêm ngữ** (让, 请, 叫). Xử lý động từ thứ 2 theo cấu trúc "để/cho/bảo". |
| **Chủ ngữ** | **SUBJ** | nsubj, top, nsubjpass | Chủ ngữ. Quan trọng để xác định đại từ nhân xưng (ngôi thứ). |
| **Bổ ngữ** | **RES** | rcomp | **Kết quả.** Tra từ điển cặp V + RES. (VD: 听懂). |
|  | **DIR** | compound:dir, attr | **Xu hướng.** (VD: 跑**出来**). Nếu có tân ngữ chèn giữa → Tách DIR ra sau tân ngữ. |
|  | **POT** | mmod, neg (trong cụm V) | **Khả năng.** Xử lý 得 (được/nổi) và 不 (không) chèn giữa V và bổ ngữ. |
| **Định ngữ** | **NMOD** | nn, amod | Định ngữ danh từ. **Luật:** Đảo ra sau danh từ (Red flower -> Hoa đỏ). |
|  | **POSS** | assmod, deg | Sở hữu (的). Dịch là "của" nếu Head là N/Pro. Bỏ nếu Head là Adj. |
|  | **RMOD** | rcmod, dec | **Mệnh đề quan hệ** (...的 + N). Dịch ngược: "N + mà +...". |
| **Trạng ngữ** | **TMOD** | tmod | **Thời gian.** Thường đứng trước V trong tiếng Trung. Tiếng Việt có thể chuyển ra sau hoặc thêm giới từ "vào". |
|  | **ADV** | advmod, dvp | Trạng từ (đã, đang, sẽ, rất...). |
| **Hư từ** | **LOC** | loc, lobj | **Phương vị từ** (上, 下, 里). **Luật:** Xóa LOC, chuyển thành Giới từ đứng đầu cụm (在...上 -> Trên...). |
|  | **PREP** | prep, pobj | Giới từ (Đối với, Tại, Từ). Tra nghĩa theo tân ngữ (pobj) của nó. |
|  | **BA** | ba | **Câu chữ Bả.** Chuyển đổi cấu trúc: S + 把 + O + V -> S + V + O (hoặc S + đem + O + V). |
|  | **BEI** | agent, pass | **Câu bị động.** Dựa vào sentiment của V để chọn "Bị" (tiêu cực) hay "Được" (tích cực). |
| **Khác** | **CLF** | clf | Lượng từ. Tra ngược theo danh từ chính. |
|  | **COOR** | cc, conj | Liên từ (和, 跟). Dịch "và/với/nhưng". |
---
## Mapping Function
```crystal
def deprel_to_drt(deprel : String, context : String? = nil) : String?
  case deprel
  # Động từ
  when "dobj"
    context == "liheci" ? "SEP" : "OBJ"
  when "ccomp", "xcomp"
    "PIV"
  # Chủ ngữ
  when "nsubj", "top", "nsubjpass"
    "SUBJ"
  # Bổ ngữ
  when "rcomp"
    context == "direction" ? "DIR" : "RES"
  when "compound:dir", "attr"
    "DIR"
  when "mmod"
    "POT"
  # Định ngữ
  when "nn", "amod"
    "NMOD"
  when "assmod", "deg"
    "POSS"
  when "rcmod", "dec"
    "RMOD"
  # Trạng ngữ
  when "tmod"
    "TMOD"
  when "advmod", "dvp"
    "ADV"
  # Hư từ
  when "loc", "lobj"
    "LOC"
  when "prep", "pobj"
    "PREP"
  when "ba"
    "BA"
  when "agent", "pass"
    "BEI"
  # Khác
  when "clf"
    "CLF"
  when "cc", "conj"
    "COOR"
  else
    nil
  end
end
```
---
## Xử lý Logic theo DRT
### 1. OBJ & SEP - Tân ngữ
```yaml
# OBJ - Tra nghĩa động từ theo tân ngữ
打+电话+OBJ: "gọi"
打+人+OBJ: "đánh"
打+<NER:PERSON>+OBJ: "đánh"  # fallback

# SEP - Động từ ly hợp (ẩn tân ngữ)
帮忙+SEP: ["giúp đỡ", null]
睡觉+SEP: ["ngủ", null]
吃饭+SEP: ["ăn cơm", null]
```
### 2. PIV - Câu sai khiến
```yaml
# Kiêm ngữ: S + V1 + O + V2
让+<N>+<V>+PIV: "để <N> <V>"
请+<N>+<V>+PIV: "mời <N> <V>"
叫+<N>+<V>+PIV: "bảo <N> <V>"
```
### 3. RES & DIR - Bổ ngữ
```yaml
# RES - Kết quả
听+懂+RES: "nghe hiểu"
看+到+RES: "nhìn thấy"
做+完+RES: "làm xong"

# DIR - Xu hướng (có thể tách khi có OBJ chèn giữa)
跑+回+DIR: "chạy về"
走+出+DIR: "đi ra"
# 跑回家来 → chạy về nhà (tách DIR)
```
### 4. POT - Khả năng
```yaml
# 得 - được/nổi
看+得+懂+POT: "nhìn hiểu được"
吃+得+完+POT: "ăn hết nổi"

# 不 - không
看+不+懂+POT: "nhìn không hiểu"
吃+不+完+POT: "ăn không hết"
```
### 5. NMOD - Định ngữ (đảo vị trí)
```yaml
# Tiếng Trung Adj+N → Tiếng Việt N+Adj
红+花+NMOD: "hoa đỏ"  # REORDER_SWAP
大+国+NMOD: "đại quốc" | "nước lớn"
```
### 6. POSS - Sở hữu (的)
```yaml
# N/Pro + 的 → "của"
我+的+书+POSS: "sách của tôi"
# Adj + 的 → bỏ 的
美丽+的+花+POSS: "hoa đẹp"
# V + 的 → "mà/để"
吃+的+东西+POSS: "đồ ăn"
```
### 7. TMOD - Thời gian
```yaml
# Có thể thêm giới từ "vào"
明天+来+TMOD: "ngày mai đến" | "vào ngày mai đến"
昨天+去+TMOD: "hôm qua đi"
```
### 8. LOC - Phương vị (biến đổi cấu trúc)
```yaml
# Trung: 在 + N + 上 → Việt: Trên + N
在+桌子+上+LOC: "trên bàn"
在+家+里+LOC: "ở nhà" | "trong nhà"
```
### 9. BA & BEI - Thể câu
```yaml
# BA - Xử trí (把)
# Cách 1: Chuyển về SVO
把+苹果+吃了+BA: "ăn táo rồi"
# Cách 2: Dùng "đem"
把+苹果+吃了+BA: "đem táo ăn rồi"

# BEI - Bị động (被)
<V:negative>+被+BEI: "bị"  # 被打 → bị đánh
<V:positive>+被+BEI: "được"  # 被表扬 → được khen
```
### 10. CLF - Lượng từ (tra ngược)
```yaml
# Key = Danh từ + Lượng từ
鱼+条+CLF: "con"
河+条+CLF: "dòng"
裤子+条+CLF: "cái"
<Animal>+条+CLF: "con"  # fallback
```
---
## Quy trình Xử lý 6 Bước (Cascading)
```
1. STRUCTURAL NORMALIZATION
   - Quét BA (把), BEI (被), LOC (phương vị)
   - Biến đổi cây trước khi dịch

2. MERGE & MWE
   - Phát hiện SEP (ly hợp) → gộp token
   - Phát hiện thành ngữ 4 chữ

3. HIGH PRIORITY LOOKUP
   - CLF (lượng từ) - tra ngược
   - RES/DIR (bổ ngữ) - phân biệt kết quả vs xu hướng

4. WSD CORE
   - OBJ để chọn nghĩa động từ
   - Ưu tiên: Exact > NER group > UTT group

5. REORDERING
   - NMOD, RMOD → đảo vị trí
   - TMOD → có thể chuyển vị trí + thêm giới từ

6. FALLBACK
   - pos-dict theo UTT
   - Hán-Việt / OOV
```
---
## Tài liệu tham khảo
- [Stanford Dependencies Chinese](https://hanlp.hankcs.com/docs/annotations/dep/sd_zh.html)
- [Dependency-based pre-ordering Trung-Việt](https://www.researchgate.net/publication/323411369)
- [Bổ ngữ xu hướng tiếng Trung](https://ctihsk.edu.vn/bo-ngu-xu-huong-trong-tieng-trung/)
- [Động từ ly hợp](https://trungtamhsk.com/bai-6-dong-tu-ly-hop-trong-tieng-trung/)
