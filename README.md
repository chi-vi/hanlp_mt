# zh2vi - Thư viện Dịch thuật Trung-Việt

Zh2Vi là thư viện Crystal hỗ trợ dịch máy từ tiếng Trung sang tiếng Việt theo phương pháp lai (Hybrid Approach), kết hợp **Quy tắc Ngôn ngữ học (Linguistic Rules)** và **Từ điển Ngữ nghĩa (Semantic Dictionary)**.

Khác với các hệ thống dịch từ điển đơn giản, Zh2Vi tận dụng **toàn bộ 5 tầng xử lý NLP** của HanLP (TOK, POS, NER, CON, DEP) để xây dựng cấu trúc ngữ pháp, tái sắp xếp trật tự từ và chọn nghĩa chính xác.

## Kiến trúc Hệ thống

Zh2Vi xử lý câu đầu vào qua pipeline 3 bước chặt chẽ:

### 1. Phân tích & Dựng cây (Input Analysis)
Hệ thống tiếp nhận kết quả phân tích đa tầng từ HanLP MTL:

| Tầng NLP | Vai trò trong Zh2Vi |
|----------|---------------------|
| **TOK** (Tokenization) | Xác định ranh giới từ vựng. |
| **POS** (Part-of-Speech) | Cung cấp thông tin từ loại cho quy tắc ngữ pháp. |
| **NER** (Named Entity) | Khóa các thực thể tên riêng (atomic nodes) để bảo toàn nghĩa. |
| **CON** (Constituency) | **Ưu tiên cao nhất**: Dùng để khớp và thay thế trực tiếp nghĩa của cả cụm từ lớn (idioms, fixed phrases) nếu có trong từ điển. Cung cấp cấu trúc để đảo trật tự. |
| **DEP** (Dependency) | **Xử lý chi tiết**: Khi cụm từ lớn (CON) không có nghĩa, hệ thống áp dụng quy luật ngữ pháp dựa trên quan hệ phụ thuộc để tái cấu trúc và chọn nghĩa cho từng từ nhỏ hơn. |

### 2. Chiến lược Dịch (Translation Strategy)
Hệ thống ưu tiên từ cấu trúc lớn đến nhỏ:

1.  **Khớp Cụm từ (Phrase Matching)**: Dựa trên cây CON và nhãn UTT (Unified Translation Tagset), kiểm tra xem cả cụm (VD: VP, NP) có trong từ điển thành ngữ/cụm từ cố định không.
    -   Sử dụng UTT để phân loại cụm từ (VD: `NP` -> `N`, `VP` -> `V`) giúp tra cứu chính xác hơn.
    -   Nếu khớp -> Dịch nguyên khối (ưu tiên cao nhất).
2.  **Áp dụng Quy luật (Grammar Rules)**: Nếu không khớp cụm lớn, sử dụng thông tin DEP và POS để:
    -   Đảo trật tự ngữ pháp (Reordering).
    -   Chọn nghĩa từ vựng dựa trên ngữ cảnh phụ thuộc (DRT).
    -   Xử lý các cấu trúc đặc biệt (Ba, Bei, De...).

### 3. Chọn nghĩa Từ vựng (Lexical Selection)
Khi xuống đến mức từ đơn (Leaf nodes), tra cứu theo độ ưu tiên:

1.  **Từ điển Phụ thuộc (DepDict)**: Dùng DRT để chọn nghĩa chính xác theo ngữ cảnh.
    -   *Ưu tiên 1 (RES)*: Bổ ngữ kết quả.
    -   *Ưu tiên 2 (OBJ)*: Tân ngữ.
    -   *Ưu tiên 3 (AGT)*: Chủ ngữ.
2.  **Từ điển POS**: Tra cứu từ đơn.
3.  **Fallback**: Hán-Việt.

## Cài đặt

Thêm vào `shard.yml`:

```yaml
dependencies:
  zh2vi:
    github: chi-vi/zh2vi
    branch: main
```

Chạy: `shards install`

## Hướng dẫn Sử dụng

### Dữ liệu đầu vào
Bạn cần có output từ HanLP MTL (multi-task learning). Zh2Vi nhận vào các mảng song song:

```crystal
require "zh2vi"

# 1. Khởi tạo
translator = Zh2Vi::Translator.load("data/pos-dict.jsonl", "data/dep-dict.jsonl", "data/hanviet.txt")

# 2. Input từ HanLP "我爱自然语言处理"
con_str = "(IP (NP (PN 我)) (VP (VV 爱) (NP (NN 自然) (NN 语言) (NN 处理))))"
cws     = ["我", "爱", "自然", "语言", "处理"]
pos     = ["PN", "VV", "NN", "NN", "NN"]
# NER (nếu có)
ner     = [] of Zh2Vi::NerSpan
# Dependency
dep     = [
  Zh2Vi::DepRel.new(0, 1, "nsubj"),
  Zh2Vi::DepRel.new(2, 4, "nn"),
  Zh2Vi::DepRel.new(3, 4, "nn"),
  Zh2Vi::DepRel.new(4, 1, "dobj")
]

# 3. Dịch
tree = translator.translate(con_str, cws, pos, ner, dep)
puts translator.output_text(tree)
# => "tôi yêu xử lý ngôn ngữ tự nhiên"
```

## Cấu trúc Từ điển

### POS Dictionary (`pos-dict.jsonl`)
Sử dụng **UTT (Unified Translation Tagset)** cho cả từ đơn và cụm từ:
- Từ đơn: `VV` -> `V`, `NN` -> `N`
- Cụm từ (Phrase): `VP` -> `V`, `NP` -> `N` (hỗ trợ dịch nguyên khối)

```json
["爱", "V", "yêu", "thích"]              // Từ đơn
["打 电话", "V", "gọi điện thoại"]        // Cụm động từ (VP)
["自然 语言 处理", "N", "xử lý ngôn ngữ tự nhiên"] // Cụm danh từ (NP)
```

### Dependency Dictionary (`dep-dict.jsonl`)
Sử dụng DRT tags (`OBJ`, `AGT`, `RES`, `NMOD`...):
```json
["水", "开", "AGT", "nước", "sôi"]
["水", "开", "OBJ", "nước", "mở"]
```

## Đóng góp
Pull Request được hoan nghênh.
