# PKU tagset to UTT tagset mapping
# PKU: 北京大学 1998 People's Daily Corpus标准
# UTT: Unified Translation Tagset (xem doc/unified-tagset.md)

module PKU2UTT
  # Map PKU tag to UTT tag
  def self.convert(pku : String) : String
    case pku.downcase
    # Danh từ
    when "n"  then "N" # Danh từ chung
    when "t"  then "N" # Thời gian → N
    when "s"  then "N" # Nơi chốn → N
    when "vn" then "N" # Danh động từ → N
    when "an" then "N" # Danh tính từ → N
    # Tên riêng
    when "nr" then "NR" # Tên người
    when "ns" then "NR" # Địa danh
    when "nt" then "NR" # Tổ chức
    when "nz" then "NR" # Tên riêng khác
    # Động từ
    when "v"  then "V" # Động từ
    when "vi" then "V" # Nội động từ
    # Tính từ
    when "a" then "A" # Tính từ
    when "b" then "A" # Từ phân biệt → A
    when "z" then "A" # Từ trạng thái → A
    # Trạng từ
    when "d"  then "D" # Phó từ
    when "ad" then "D" # Phó tính từ → trạng từ
    when "vd" then "D" # Phó động từ → trạng từ
    # Đại từ
    when "r" then "PN" # Đại từ
    # Lượng từ / Số
    when "m" then "M" # Số từ
    when "q" then "M" # Lượng từ
    # Hư từ
    when "p" then "F" # Giới từ
    when "u" then "F" # Trợ từ (的, 了, 着, 过)
    when "f" then "F" # Phương vị (上, 下, 东)
    # Thán từ
    when "e" then "I" # Thán từ
    when "y" then "I" # Trợ từ ngữ khí
    when "o" then "I" # Tượng thanh
    # Khác
    when "c" then "X" # Liên từ
    when "w" then "X" # Dấu câu
    when "i" then "X" # Thành ngữ
    when "l" then "X" # Cụm từ quen dùng
    when "j" then "X" # Viết tắt
    else          "X" # Mặc định
    end
  end
end
