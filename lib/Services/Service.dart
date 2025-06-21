// ฟังก์ชั่นสำหรับตัดคำเกินให้เป็น Hello World...
String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}...';
}