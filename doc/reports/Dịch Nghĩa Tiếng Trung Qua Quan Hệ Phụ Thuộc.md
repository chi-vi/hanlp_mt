# **Báo cáo Nghiên cứu Chuyên sâu: Tối ưu hóa Dịch máy Trung-Việt thông qua Phân tích Quan hệ Phụ thuộc (Dependency Parsing) và Mở rộng Hệ thống Tagset Ngữ nghĩa**

## **Tóm tắt Điều hành (Executive Summary)**

Báo cáo này được biên soạn nhằm phục vụ giai đoạn phát triển thứ ba của hệ thống dịch máy Trung-Việt, tập trung vào việc giải quyết bài toán đa nghĩa của từ (Word Sense Disambiguation \- WSD) và tái sắp xếp trật tự từ (Reordering) thông qua phân tích cú pháp phụ thuộc. Dựa trên nền tảng cây ngữ pháp HanLP chuẩn Stanford Dependencies (SD) và bộ nhãn từ loại UTT (Unified Translation Tagset) đã được thiết lập 1, báo cáo đi sâu vào phân tích tính đầy đủ và chính xác của tệp cấu hình dep-tag.md do người dùng đề xuất.  
Phân tích cho thấy, mặc dù việc phân loại các quan hệ phụ thuộc thành ba nhóm "Ảnh hưởng trực tiếp", "Ảnh hưởng gián tiếp" và "Không ảnh hưởng" là một hướng tiếp cận hợp lý về mặt vĩ mô, nhưng nội dung hiện tại của dep-tag.md còn thiếu sót nghiêm trọng trong việc xử lý các cấu trúc đặc thù của tiếng Trung như câu chữ "Bả" (把 \- disposal), câu bị động "Bị" (被 \- passive), kết cấu bổ ngữ xu hướng phức hợp (compound directional complements), và các động từ ly hợp (separable verbs). Đặc biệt, việc xếp loại các hư từ (function words) và giới từ (prepositions) vào nhóm "Không ảnh hưởng" 1 là một nhận định rủi ro có thể dẫn đến sai lệch cấu trúc câu trong tiếng Việt.  
Báo cáo đề xuất một kiến trúc mở rộng cho hệ thống dep-dict (từ điển phụ thuộc), nâng cấp bộ nhãn DRT (Dependency Relation Tags) từ 6 nhãn cơ bản lên hệ thống 12 nhãn chi tiết, tích hợp cơ chế "Cascade Priority" (Ưu tiên tầng) để xử lý các xung đột ngữ nghĩa. Báo cáo cũng cung cấp các thuật toán cụ thể để chuyển đổi cấu trúc cú pháp (Structural Transfer) dựa trên các quan hệ phụ thuộc, đảm bảo bản dịch tiếng Việt không chỉ chính xác về nghĩa từ vựng mà còn tự nhiên về ngữ pháp.2

## ---

**1\. Cơ sở Lý luận và Đánh giá Hiện trạng Hệ thống**

### **1.1. Tầm quan trọng của Quan hệ Phụ thuộc trong Dịch Trung-Việt**

Dịch máy giữa tiếng Trung và tiếng Việt thường gặp phải ảo giác về sự tương đồng (Isomorphism) do cả hai đều chia sẻ trật tự câu cơ bản SVO (Chủ ngữ \- Động từ \- Tân ngữ). Tuy nhiên, ở tầng sâu hơn, sự khác biệt về vị trí của định ngữ (Modifier), cách xử lý các bổ ngữ kết quả (Resultative Complements) và sự hiện diện của các hư từ chỉ phương vị (Localizers) tạo ra những hố sâu ngăn cách về ngữ nghĩa mà phương pháp dịch theo từ (Word-to-Word) hoặc thống kê đơn thuần không thể giải quyết.4  
Việc sử dụng cây ngữ pháp phụ thuộc (Dependency Tree) cho phép hệ thống "nhìn thấy" mối liên kết ngữ nghĩa giữa các từ xa nhau trong câu, thay vì chỉ xét các từ lân cận (N-gram). Trong bối cảnh dự án này, việc người dùng đã tích hợp thành công HanLP 6 và xây dựng bộ UTT 1 là tiền đề vững chắc. Thách thức còn lại là định nghĩa *luật chuyển đổi* (Transformation Rules) từ các nhãn Stanford Dependencies (SD) sang các hành động dịch thuật cụ thể.

### **1.2. Kiểm toán Tệp dep-tag.md và Các Lỗ hổng Chiến lược**

Tệp dep-tag.md hiện tại phân loại các quan hệ phụ thuộc dựa trên mức độ ảnh hưởng đến nghĩa của từ. Dưới đây là phân tích chi tiết về các lỗ hổng (gaps) được phát hiện khi đối chiếu với tài liệu ngữ pháp chuyên sâu và các nghiên cứu về dịch máy Trung-Việt.8

#### **Bảng 1: Đánh giá Phân loại Hiện tại trong dep-tag.md và Các Sai số Phát hiện**

| Nhóm Phân loại (User) | Các Quan hệ (HanLP SD) | Đánh giá Mức độ Rủi ro | Phân tích Lỗ hổng và Sai sót |
| :---- | :---- | :---- | :---- |
| **✅ Ảnh hưởng trực tiếp** | clf, dobj, rcomp, tmod | Thấp | Phân loại đúng, nhưng xử lý chưa đủ sâu. Ví dụ: rcomp không chỉ thay đổi nghĩa động từ chính mà còn quyết định cấu trúc câu tiếng Việt (cần tách động từ).11 |
| **⚠️ Ảnh hưởng gián tiếp** | nn, nsubj, top, rcmod | Trung bình | Đánh giá thấp vai trò của nn (Noun Compound). Trong tiếng Việt, nn kích hoạt đảo ngược trật tự từ (Word Reordering), là yếu tố sống còn của độ trôi chảy.3 |
| **❌ Không ảnh hưởng** | punct, cc, asp, ba, bei, cop, loc | **Rất Cao** | **Sai lầm nghiêm trọng.** ba, bei, loc (Localizer), và prep (Preposition) là xương sống cấu trúc câu. Nếu bỏ qua, câu dịch sẽ vô nghĩa hoặc sai ngữ pháp hoàn toàn.12 |

## ---

**2\. Phân tích Chi tiết: Nhóm Quan hệ "Ảnh hưởng Trực tiếp" (Direct Influence)**

Nhóm này bao gồm các quan hệ thay đổi trực tiếp ngữ nghĩa từ vựng của từ trung tâm (Head) hoặc từ phụ thuộc (Dependent). Tuy nhiên, báo cáo này sẽ mở rộng phạm vi phân tích để bao gồm cả các trường hợp *Động từ Ly hợp* (Separable Verbs) và *Bổ ngữ Xu hướng* (Directional Complements), những yếu tố mà dep-tag.md chưa đề cập đầy đủ.

### **2.1. Quan hệ Tân ngữ Trực tiếp (dobj) và Bài toán Đa nghĩa Động từ**

Trong tiếng Trung, động từ thường mang tính "nhẹ" (light verbs) và dựa vào tân ngữ để xác định nghĩa cụ thể. Ví dụ điển hình là động từ 打 (dǎ).14

#### **2.1.1. Cơ chế Chọn nghĩa Đa chiều**

Cơ chế tra cứu hiện tại trong dep-dict là \`\`. Tuy nhiên, để xử lý triệt để, ta cần tích hợp thông tin ngữ nghĩa từ bộ UTT (Tagset từ loại).

* **Trường hợp 1: Tân ngữ Cụ thể.**  
  * Cặp: 打 \+ 电话 (điện thoại) \-\> dobj.  
  * Dịch: Gọi (điện thoại).  
  * Logic: Tra cứu chính xác key \= "打:电话:OBJ".  
* **Trường hợp 2: Tân ngữ theo Nhóm Ngữ nghĩa (Semantic Class).**  
  * Cặp: 打 \+ \`\` (Người).  
  * Dịch: Đánh (người).  
  * Logic: Nếu không tìm thấy cặp từ chính xác, hệ thống phải fallback về key \= "打:NER\_PERSON:OBJ".  
  * Cặp: 打 \+ \[N:Vehicle\] (Xe cộ \- ví dụ: taxi, xe).  
  * Dịch: Bắt (xe), Gọi (taxi).  
  * *Insight:* Việc bổ sung cơ chế fallback theo nhóm UTT 1 là bắt buộc để giảm kích thước từ điển.

#### **2.1.2. Xử lý Động từ Ly hợp (Separable Verbs \- Liheci)**

Đây là một thiếu sót lớn trong dep-tag.md. Các động từ ly hợp như 吃饭 (ăn cơm), 睡觉 (ngủ), 帮忙 (giúp đỡ) khi phân tích cú pháp sẽ xuất hiện dưới dạng quan hệ dobj.

* **Vấn đề:** Nếu dịch máy móc từng từ:  
  * 帮忙 (bāng máng) \-\> bāng (giúp) \+ máng (bận rộn) \-\> "Giúp bận rộn" (Sai).  
  * HanLP SD: bāng \--dobj--\> máng.  
* **Giải pháp:** Cần định nghĩa một nhãn phụ hoặc danh sách đen (blacklist) cho các cặp dobj là từ ly hợp.  
  * **Logic:** Nếu cặp (V, N) thuộc danh sách Liheci 16, bản dịch của N sẽ là NULL (rỗng), và bản dịch của V sẽ bao hàm cả nghĩa của N.  
  * Ví dụ: \`\`.

### **2.2. Hệ thống Bổ ngữ: Kết quả (rcomp) và Xu hướng**

Người dùng đã gộp chung rcomp vào nhãn RES. Điều này không đủ vì tiếng Việt phân biệt rất rõ giữa "Kết quả" (trạng thái hoàn thành) và "Xu hướng" (sự di chuyển).

#### **2.2.1. Bổ ngữ Kết quả (Resultative)**

* **Cấu trúc:** V1 \+ V2 (chỉ kết quả).  
* **Ví dụ:** 看 (nhìn) \+ 懂 (hiểu) \-\> rcomp.  
* **Dịch:** Nhìn \+ hiểu (hoặc Xem hiểu).  
* **Cơ chế:** Tra cứu trực tiếp cặp từ. Tuy nhiên, cần chú ý đến biến thể phủ định 看不懂 (nhìn không hiểu) hoặc khả năng 看得懂 (nhìn có thể hiểu). Hệ thống cần kiểm tra sự tồn tại của từ phủ định (neg) hoặc trợ từ (de) nằm giữa.18

#### **2.2.2. Bổ ngữ Xu hướng (Directional \- Cần bổ sung)**

Đây là phần dep-tag.md còn thiếu. Tiếng Trung dùng động từ xu hướng kép (Compound Directional Complements) rất phức tạp, tiếng Việt cần tách chúng ra.11

* **Ví dụ Phức tạp:** 跑回家来 (Chạy về nhà).  
  * HanLP SD: 跑 (Root) \--rcomp--\> 回. 回 \--dobj--\> 家. 回 \--rcomp--\> 来.  
  * **Thách thức:** Cấu trúc "V \+ Xu hướng 1 \+ Tân ngữ \+ Xu hướng 2".  
  * **Tiếng Việt:** V \+ Xu hướng 1 \+ Tân ngữ. (Từ 来/去 cuối câu thường bị lược bỏ hoặc dịch thành "về/đến" tùy ngữ cảnh).  
* **Giải pháp:** Tạo nhãn DIR riêng biệt. Khi gặp nhãn DIR, áp dụng luật tái sắp xếp:  
  * *Input:* V \+ DIR1 \+ OBJ \+ DIR2.  
  * *Output:* Dịch(V) \+ Dịch(DIR1) \+ Dịch(OBJ). (Bỏ qua DIR2 nếu nó chỉ mang tính chất ngữ khí lai/qu rỗng).

### **2.3. Lượng từ và Số từ (clf, nummod)**

Quan hệ clf (Classifier) kết nối danh từ với lượng từ. Đây là quan hệ 1-nhiều cực kỳ quan trọng.20

* **Vấn đề:** Một lượng từ tiếng Trung (như 条 \- tiáo) có thể dịch thành nhiều từ tiếng Việt tùy thuộc vào danh từ đi kèm.  
  * 一条鱼 (cá) \-\> con cá.  
  * 一条河 (sông) \-\> dòng sông.  
  * 一条裤子 (quần) \-\> cái quần.  
  * 一条消息 (tin tức) \-\> bản tin.  
* **Cơ chế Đề xuất:** Tra cứu ngược (Reverse Lookup). Thay vì tra Head(Lượng từ) \+ Child(Danh từ), ta tra Child(Danh từ) \+ Head(Lượng từ). Nghĩa của lượng từ được quy định bởi danh từ.

## ---

**3\. Tái cấu trúc Nhóm Quan hệ "Ảnh hưởng Gián tiếp" và "Không ảnh hưởng"**

Phần này là trọng tâm của việc sửa chữa các sai sót trong dep-tag.md. Chúng ta phải chuyển các quan hệ cấu trúc (Structural Relations) từ trạng thái "bị bỏ qua" sang trạng thái "xử lý ưu tiên" (Priority Handling).

### **3.1. Cuộc cách mạng về Trật tự từ: nn và amod**

Trong dep-tag.md, nn (Noun Compound Modifier) được coi là ảnh hưởng gián tiếp. Thực tế, nó quyết định trật tự từ.3

* **Quy tắc:** Tiếng Trung là Head-Final (Định ngữ trước, Danh từ sau). Tiếng Việt là Head-Initial (Danh từ trước, Định ngữ sau).  
* **Ví dụ amod (Tính từ):**  
  * Trung: 红 (Đỏ) \+ 花 (Hoa). (Adj \+ N).  
  * Việt: Hoa \+ hồng. (N \+ Adj).  
  * **Hành động:** Khi gặp amod, hệ thống phải kích hoạt cờ REORDER\_SWAP.  
* **Ngoại lệ (Sino-Vietnamese):**  
  * Trung: 大 (Đại) \+ 国 (Quốc).  
  * Việt: Đại quốc (Giữ nguyên trật tự Hán Việt) HOẶC Nước lớn (Đảo trật tự thuần Việt).  
  * *Giải pháp:* Sử dụng tag UTT NR hoặc từ điển Hán Việt để quyết định. Nếu dịch theo nghĩa Hán Việt, giữ nguyên trật tự. Nếu dịch thuần Việt, phải đảo.

### **3.2. Cấu trúc Sở hữu và Định ngữ (assmod, dnp)**

Quan hệ assmod thường gắn liền với trợ từ 的 (de).

* **Vấn đề:** de không phải lúc nào cũng dịch là "của".  
  * 我的书 (Sách của tôi) \-\> của.  
  * 美丽的花 (Hoa đẹp) \-\> de bị bỏ, dịch tính từ liền sau danh từ.  
  * 吃的东西 (Đồ để ăn) \-\> de dịch là "để" hoặc "mà".  
* **Giải pháp:** Phân tích từ loại của từ bổ nghĩa (Modifier).  
  * Nếu Mod là PN (Đại từ) hoặc N (Danh từ) \-\> Dịch "của".  
  * Nếu Mod là A (Tính từ) \-\> Bỏ "của", đảo ngữ.  
  * Nếu Mod là V (Động từ) \-\> Dịch là "mà" hoặc "để".

### **3.3. Nhóm "Tử huyệt" bị bỏ quên: loc, ba, bei, prep**

Đây là những phần phải được bổ sung ngay lập tức vào hệ thống.

#### **3.3.1. Phương vị từ (loc \- Localizer)**

Người dùng xếp loc vào nhóm "Không ảnh hưởng".1 Đây là sai lầm vì tiếng Việt sử dụng Giới từ (Preposition) thay vì Phương vị từ (Postposition).

* **Cấu trúc Trung:** 在 (Giới từ) \+ 桌子 (Danh từ) \+ 上 (Phương vị từ \- Head của cụm).  
  * HanLP SD: zài \--pobj--\> zhuōzi. zhuōzi \--loc--\> shàng.  
* **Cấu trúc Việt:** Trên (Giới từ) \+ bàn (Danh từ).  
* **Thuật toán Chuyển đổi:**  
  1. Phát hiện quan hệ loc (shàng phụ thuộc zhuōzi).  
  2. Lấy nghĩa của từ loc (shàng \-\> trên).  
  3. **Xóa** từ loc ở cuối cụm.  
  4. **Thay thế** hoặc **Kết hợp** với giới từ đứng đầu (zài) bằng nghĩa của loc.  
  5. Kết quả: Biến đổi Tại... trên thành Trên....

#### **3.3.2. Câu chữ "Bả" (ba \- Disposal)**

Cấu trúc S \+ 把 \+ O \+ V hoàn toàn xa lạ với ngữ pháp SVO của tiếng Việt.13

* **HanLP SD:** ba (marker).  
* **Dịch:**  
  * Cách 1 (Dùng từ chức năng): Dịch 把 là đem hoặc lấy.  
    * 他把苹果吃了 \-\> Anh ấy đem táo ăn rồi.  
  * Cách 2 (Đảo cấu trúc \- Tự nhiên hơn): Chuyển về SVO.  
    * Anh ấy ăn táo rồi.  
* **Khuyến nghị:** Đối với máy dịch, cách 1 an toàn hơn. Cần thêm nhãn VOICE hoặc DISPOSAL vào hệ thống DRT.

#### **3.3.3. Câu Bị động (bei \- Passive)**

Quan hệ nsubjpass hoặc agent trong HanLP SD.

* **Vấn đề:** Tiếng Việt phân biệt Bị (tiêu cực) và Được (tích cực).12 Tiếng Trung dùng 被 cho cả hai (dù xu hướng gốc là tiêu cực, nhưng văn viết hiện đại dùng trung tính).  
* **Thuật toán Sentiment:**  
  * Tạo danh sách "Động từ tiêu cực" (đánh, mắng, phạt, giết, trộm). \-\> Dịch bị.  
  * Tạo danh sách "Động từ tích cực" (khen, thưởng, yêu, thăng chức). \-\> Dịch được.  
  * Còn lại: Mặc định là được nếu trang trọng, hoặc bị nếu ngữ cảnh rủi ro.

## ---

**4\. Đề xuất Hệ thống Tagset Mở rộng (Extended-DRT)**

Dựa trên phân tích trên, bộ 6 nhãn DRT ban đầu (OBJ, RES, MOD, ADV, NUM, PP) là không đủ. Báo cáo đề xuất hệ thống 14 nhãn chi tiết sau đây để bao phủ các yêu cầu còn thiếu.

### **Bảng 2: Hệ thống Nhãn Quan hệ Phụ thuộc Mở rộng (Extended-DRT)**

| Nhóm | Nhãn DRT Mới | Tương ứng HanLP SD | Mô tả Chức năng Dịch thuật & Xử lý |
| :---- | :---- | :---- | :---- |
| **Cốt lõi** | **OBJ-V** | dobj | Tân ngữ chuẩn. Dùng để tra cứu nghĩa động từ. |
|  | **OBJ-LIHE** | dobj | Tân ngữ của động từ ly hợp. **Hành động:** Ẩn bản dịch của tân ngữ, gộp nghĩa vào động từ. |
|  | **SUBJ** | nsubj, top | Chủ ngữ. Ít đổi nghĩa nhưng quan trọng để xác định ngôi (Đại từ nhân xưng). |
| **Bổ ngữ** | **RES** | rcomp | Bổ ngữ kết quả. Dịch: xong, được, thấy, nổi. |
|  | **DIR** | rcomp, attr, compound:dir | Bổ ngữ xu hướng. Dịch: ra, vào, lên, xuống. **Hành động:** Tách khỏi động từ nếu có tân ngữ chèn giữa. |
|  | **POT** | mmod (modal) | Bổ ngữ khả năng (de/bu). Dịch: có thể, không thể. |
| **Định ngữ** | **MOD-N** | nn, amod | Định ngữ cho danh từ. **Hành động:** Đảo trật tự từ (N \+ Adj). |
|  | **MOD-POSS** | assmod | Định ngữ sở hữu (de). **Hành động:** Thêm từ của hoặc xóa de tùy ngữ cảnh. |
|  | **MOD-REL** | rcmod, dec | Mệnh đề quan hệ. Dịch: mà, người mà, nơi mà. |
| **Số lượng** | **CLF** | clf | Lượng từ. Tra cứu ngược dựa trên Danh từ chính. |
|  | **NUM** | nummod | Số từ. Dịch số (lưu ý: er vs liang \-\> hai). |
| **Cấu trúc** | **LOC** | loc, lobj | Phương vị từ. **Hành động:** Biến đổi thành Giới từ đầu cụm. |
|  | **PREP** | prep, pobj | Giới từ. Xác định nghĩa giới từ dựa trên tân ngữ của nó (Thời gian/Địa điểm). |
|  | **VOICE** | ba, bei, agent | Thể bị động/chủ động. Chọn bị/được hoặc đem/lấy. |

## ---

**5\. Kiến trúc Quy trình Tra cứu và Tích hợp (Implementation Workflow)**

Để trả lời câu hỏi "cần bổ sung gì" của người dùng, phần này mô tả quy trình tích hợp các thông tin trên vào máy dịch. Quy trình này khắc phục sự đơn giản quá mức của quy trình tra cứu tuyến tính ban đầu.

### **5.1. Cấu trúc Từ điển Phụ thuộc (dep-dict)**

Thay vì cấu trúc phẳng, từ điển cần hỗ trợ tra cứu theo khuôn mẫu (pattern matching).  
Dữ liệu mẫu:

JSON

{  
  "key": "打+OBJ+电话", "trans": "gọi", "type": "exact"  
},  
{  
  "key": "打+OBJ+\<NER:PERSON\>", "trans": "đánh", "type": "semantic\_class"  
},  
{  
  "key": "一条+CLF+\<N:Animal\>", "trans": "con", "type": "reverse\_lookup"  
},  
{  
  "key": "在+PREP+\<N:Time\>", "trans": "vào", "type": "prep\_logic"  
}

### **5.2. Thuật toán Xử lý 6 Bước (Cascading Logic)**

Để đảm bảo tính chính xác, hệ thống không được tra cứu ngẫu nhiên mà phải tuân thủ thứ tự ưu tiên sau:

1. **Bước 1: Chuẩn hóa Cấu trúc (Structural Normalization)**  
   * Quét cây cú pháp để tìm các quan hệ cấu trúc lớn: VOICE (bị động/bả), LOC (phương vị).  
   * Thực hiện biến đổi cây (Tree Transformation) trước khi dịch từ. Ví dụ: Chuyển Zai... Shang thành Tren....  
2. **Bước 2: Phát hiện và Gộp Từ (Merge & MWE)**  
   * Kiểm tra OBJ-LIHE (Liheci). Nếu phát hiện gặp \+ mặt, gộp thành token ảo gặp\_mặt để dịch là gặp.  
   * Kiểm tra Thành ngữ (Chengyu) 4 chữ.  
3. **Bước 3: Tra cứu Quan hệ Chặt (High Priority)**  
   * Xử lý CLF (Lượng từ) và RES/DIR (Bổ ngữ). Đây là những thành phần 1-1 bắt buộc phải đúng ngữ pháp.  
4. **Bước 4: Tra cứu Động từ Đa nghĩa (WSD Core)**  
   * Sử dụng dobj để chọn nghĩa động từ chính.  
   * Áp dụng ưu tiên: Khớp chính xác từ \> Khớp nhóm NER \> Khớp nhóm POS.  
5. **Bước 5: Xử lý Trật tự Từ (Reordering)**  
   * Áp dụng luật đảo ngữ cho MOD-N và MOD-REL.  
   * Xử lý vị trí của Trạng từ (advmod): Đưa trạng từ chỉ tần suất lên trước động từ, trạng từ chỉ mức độ ra sau tính từ (tùy loại, ví dụ: hen trước, ji le sau).  
6. **Bước 6: Fallback và Hán Việt**  
   * Nếu không có luật nào khớp, sử dụng nghĩa mặc định trong từ điển đơn (pos-dict).  
   * Nếu từ điển đơn không có, chuyển đổi sang âm Hán Việt (đây là lợi thế đặc biệt của cặp ngôn ngữ Trung-Việt).2

## ---

**6\. Kết luận và Kiến nghị**

Dự án thiết kế máy dịch Trung-Việt của người dùng đang đi đúng hướng với việc áp dụng HanLP và UTT. Tuy nhiên, tệp dep-tag.md hiện tại còn quá sơ khai để xử lý sự phức tạp của ngữ pháp tiếng Trung khi ánh xạ sang tiếng Việt.  
**Các điểm chính cần bổ sung ngay lập tức:**

1. **Loại bỏ nhóm "Không ảnh hưởng":** Các quan hệ hư từ (ba, bei, de, le, zài) là yếu tố quyết định cấu trúc câu tiếng Việt, cần được xây dựng module xử lý riêng biệt.  
2. **Tách nhãn DRT:** Phân biệt rạch ròi giữa Kết quả và Xu hướng; giữa Danh từ ghép (nn) và Sở hữu cách (assmod).  
3. **Cơ chế Đảo ngữ:** Tích hợp luật đảo vị trí cho cụm danh từ và cụm phương vị từ.  
4. **Xử lý Động từ Ly hợp:** Thêm danh sách đen để tránh dịch thừa tân ngữ rỗng.

Bằng cách tích hợp hệ thống Extended-DRT và thuật toán xử lý 6 bước được đề xuất trong báo cáo này, hệ thống dịch máy sẽ vượt qua được giới hạn của việc dịch từ-đối-từ, tạo ra các bản dịch có cấu trúc tự nhiên, chính xác về ngữ nghĩa và văn phong tiếng Việt.

### ---

**Tài liệu Tham khảo & Trích dẫn**

Trong báo cáo này, các phân tích dựa trên dữ liệu từ:

* Định nghĩa Tagset UTT và Dep-Tag từ người dùng.1  
* Chuẩn Stanford Dependencies cho tiếng Trung.7  
* Nghiên cứu về Dịch máy và Đa nghĩa trong cặp ngôn ngữ Trung-Việt.2  
* Các cấu trúc ngữ pháp đặc thù: Bổ ngữ 11, Câu bị động 12, Từ ly hợp 16, Đa nghĩa động từ "Da".14

#### **Works cited**

1. dep-tag.md  
2. Application of the transformer model algorithm in chinese word sense disambiguation: a case study in chinese language \- PMC \- PubMed Central, accessed February 7, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC10943221/](https://pmc.ncbi.nlm.nih.gov/articles/PMC10943221/)  
3. (PDF) Dependency-based pre-ordering of preposition phrases in Chinese-Vietnamese machine translation \- ResearchGate, accessed February 7, 2026, [https://www.researchgate.net/publication/323411369\_Dependency-based\_pre-ordering\_of\_preposition\_phrases\_in\_Chinese-Vietnamese\_machine\_translation](https://www.researchgate.net/publication/323411369_Dependency-based_pre-ordering_of_preposition_phrases_in_Chinese-Vietnamese_machine_translation)  
4. Vietnamese to Chinese Machine Translation via Chinese Character as Pivot \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/Y13-1024.pdf](https://aclanthology.org/Y13-1024.pdf)  
5. (PDF) Word Re-Segmentation in Chinese-Vietnamese Machine Translation \- ResearchGate, accessed February 7, 2026, [https://www.researchgate.net/publication/309754548\_Word\_Re-Segmentation\_in\_Chinese-Vietnamese\_Machine\_Translation](https://www.researchgate.net/publication/309754548_Word_Re-Segmentation_in_Chinese-Vietnamese_Machine_Translation)  
6. Dependency Parsing — HanLP Documentation \- Hankcs, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/annotations/dep/index.html](https://hanlp.hankcs.com/docs/annotations/dep/index.html)  
7. Stanford Dependencies Chinese — HanLP Documentation, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/annotations/dep/sd\_zh.html](https://hanlp.hankcs.com/docs/annotations/dep/sd_zh.html)  
8. Universal Dependencies for Mandarin Chinese \- PolyU Institutional Research Archive, accessed February 7, 2026, [https://ira.lib.polyu.edu.hk/bitstream/10397/92463/1/Poiret\_Dependencies\_Mandarin\_Chinese.pdf](https://ira.lib.polyu.edu.hk/bitstream/10397/92463/1/Poiret_Dependencies_Mandarin_Chinese.pdf)  
9. Discriminative Reordering with Chinese Grammatical Relations Features \- The Stanford Natural Language Processing Group, accessed February 7, 2026, [https://nlp.stanford.edu/pubs/ssst09-chang.pdf](https://nlp.stanford.edu/pubs/ssst09-chang.pdf)  
10. dependency-based pre-ordering of preposition phrases in chinese-vietnamese machine translation \- ICIC Express Letters, Part B: Applications, accessed February 7, 2026, [http://www.icicelb.org/ellb/contents/2018/3/elb-09-03-13.pdf](http://www.icicelb.org/ellb/contents/2018/3/elb-09-03-13.pdf)  
11. Bổ ngữ xu hướng trong tiếng Trung là gì? Phân loại và cách dùng, accessed February 7, 2026, [https://ctihsk.edu.vn/bo-ngu-xu-huong-trong-tieng-trung-la-gi-phan-loai-va-cach-dung/](https://ctihsk.edu.vn/bo-ngu-xu-huong-trong-tieng-trung-la-gi-phan-loai-va-cach-dung/)  
12. Chinh phục ngữ pháp tiếng Trung về câu bị động, accessed February 7, 2026, [https://trungtamtiengtrung.edu.vn/blog/ngu-phap-tieng-trung-ve-cau-bi-dong-1192/](https://trungtamtiengtrung.edu.vn/blog/ngu-phap-tieng-trung-ve-cau-bi-dong-1192/)  
13. Cách dùng câu chữ “被”- câu bị động trong Tiếng Trung (被字句）, accessed February 7, 2026, [https://www.tiengtrungnihao.com/post/c%C3%A1ch-d%C3%B9ng-c%C3%A2u-ch%E1%BB%AF-%E8%A2%AB-c%C3%A2u-b%E1%BB%8B-%C4%91%E1%BB%99ng-trong-ti%E1%BA%BFng-trung-%E8%A2%AB%E5%AD%97%E5%8F%A5%EF%BC%89](https://www.tiengtrungnihao.com/post/c%C3%A1ch-d%C3%B9ng-c%C3%A2u-ch%E1%BB%AF-%E8%A2%AB-c%C3%A2u-b%E1%BB%8B-%C4%91%E1%BB%99ng-trong-ti%E1%BA%BFng-trung-%E8%A2%AB%E5%AD%97%E5%8F%A5%EF%BC%89)  
14. The Polysemy of the Chinese Action Verb “Dǎ” and Its Implications in Child Language Acquisition \- DR-NTU, accessed February 7, 2026, [https://dr.ntu.edu.sg/bitstreams/56ade188-0bf5-4d15-9202-aacce42013ae/download](https://dr.ntu.edu.sg/bitstreams/56ade188-0bf5-4d15-9202-aacce42013ae/download)  
15. A Longitudinal Study of the Acquisition of the Polysemous Verb 打 dǎ in Mandarin Chinese, accessed February 7, 2026, [https://www.mdpi.com/2226-471X/5/2/23](https://www.mdpi.com/2226-471X/5/2/23)  
16. Bài 6: Động Từ Ly Hợp Trong Tiếng Trung, accessed February 7, 2026, [https://trungtamhsk.com/bai-6-dong-tu-ly-hop-trong-tieng-trung/](https://trungtamhsk.com/bai-6-dong-tu-ly-hop-trong-tieng-trung/)  
17. Ngữ pháp về động từ li hợp trong tiếng Trung 离合动词, accessed February 7, 2026, [https://prepedu.com/vi/blog/dong-tu-li-hop](https://prepedu.com/vi/blog/dong-tu-li-hop)  
18. Bổ ngữ khả năng trong tiếng Trung là gì? Các loại bổ ngữ thường gặp, accessed February 7, 2026, [https://thanhmaihsk.edu.vn/tim-hieu-ve-bo-ngu-kha-nang-trong-tieng-trung/](https://thanhmaihsk.edu.vn/tim-hieu-ve-bo-ngu-kha-nang-trong-tieng-trung/)  
19. Cách dùng bổ ngữ xu hướng trong tiếng Trung chi tiết\!, accessed February 7, 2026, [https://prepedu.com/vi/blog/bo-ngu-xu-huong-trong-tieng-trung](https://prepedu.com/vi/blog/bo-ngu-xu-huong-trong-tieng-trung)  
20. 50+ Lượng Từ Trong Tiếng Trung Cơ Bản Và Cách Sử Dụng, accessed February 7, 2026, [https://nihaoma-mandarin.com/vi/goc-hoc-tap/cac-luong-tu-trong-tieng-trung/](https://nihaoma-mandarin.com/vi/goc-hoc-tap/cac-luong-tu-trong-tieng-trung/)  
21. Lượng Từ Trong Tiếng Trung: Những Điều Cần Biết, accessed February 7, 2026, [https://www.tiengtrungnihao.com/post/luong-tu-trong-tieng-trung-nhung-%C4%91ieu-can-biet](https://www.tiengtrungnihao.com/post/luong-tu-trong-tieng-trung-nhung-%C4%91ieu-can-biet)  
22. Cách dùng 50+ lượng từ trong tiếng Trung thông dụng, accessed February 7, 2026, [https://prepedu.com/vi/blog/luong-tu-trong-tieng-trung](https://prepedu.com/vi/blog/luong-tu-trong-tieng-trung)  
23. Cách sử dụng các trợ từ 的, 得, 地\-de trong khẩu ngữ tiếng Trung \- YouTube, accessed February 7, 2026, [https://www.youtube.com/watch?v=wHyzwfAXdAc](https://www.youtube.com/watch?v=wHyzwfAXdAc)  
24. The Stanford typed dependencies representation, accessed February 7, 2026, [https://nlp.stanford.edu/pubs/dependencies-coling08.pdf](https://nlp.stanford.edu/pubs/dependencies-coling08.pdf)  
25. Stanford Dependencies English — HanLP Documentation, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/annotations/dep/sd\_en.html](https://hanlp.hankcs.com/docs/annotations/dep/sd_en.html)  
26. Machine Translation for Vietnamese-Chinese and Vietnamese-Lao language pair \- arXiv, accessed February 7, 2026, [https://arxiv.org/pdf/2501.08621](https://arxiv.org/pdf/2501.08621)