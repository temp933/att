// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:table_calendar/table_calendar.dart';
// import '../providers/attendance_provider.dart';

// class AttendanceCalendarScreen extends StatefulWidget {
//   const AttendanceCalendarScreen({super.key});

//   @override
//   State<AttendanceCalendarScreen> createState() =>
//       _AttendanceCalendarScreenState();
// }

// class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
//   DateTime focusedDay = DateTime.now();
//   DateTime selectedDay = DateTime.now();

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final bool isDesktop = size.width >= 900;
//     final double horizontalPadding = isDesktop ? size.width * 0.12 : 16;
//     final double spacing = isDesktop ? 20 : 12;
//     final provider = context.watch<AttendanceProvider>();

//     return Scaffold(
//       backgroundColor: Colors.grey.shade100,
//       appBar: AppBar(
//         title: const Text("Attendance Calendar"),
//         backgroundColor: Colors.indigo,
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.symmetric(
//           horizontal: horizontalPadding,
//           vertical: 24,
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             /// CALENDAR
//             TableCalendar(
//               firstDay: DateTime.utc(2023, 1, 1),
//               lastDay: DateTime.utc(2035, 12, 31),
//               focusedDay: focusedDay,
//               selectedDayPredicate: (day) => isSameDay(day, selectedDay),
//               onDaySelected: (selected, focused) {
//                 setState(() {
//                   selectedDay = selected;
//                   focusedDay = focused;
//                 });
//               },
//               calendarBuilders: CalendarBuilders(
//                 defaultBuilder: (context, day, _) {
//                   final type = provider.getAttendance(day);
//                   if (type == null) return null;
//                   return _dayCell(
//                     day.day.toString(),
//                     _getColor(type),
//                     isDesktop,
//                   );
//                 },
//                 todayBuilder: (context, day, _) {
//                   final type = provider.getAttendance(day);
//                   return _dayCell(
//                     day.day.toString(),
//                     type != null ? _getColor(type) : Colors.indigo,
//                     isDesktop,
//                   );
//                 },
//                 selectedBuilder: (context, day, _) =>
//                     _dayCell(day.day.toString(), Colors.black, isDesktop),
//               ),
//             ),
//             SizedBox(height: spacing),

//             /// LEGEND
//             Wrap(
//               spacing: spacing,
//               children: [
//                 _Legend(
//                   color: Colors.green,
//                   label: "P - Present",
//                   isDesktop: isDesktop,
//                 ),
//                 _Legend(
//                   color: Colors.red,
//                   label: "A - Absent",
//                   isDesktop: isDesktop,
//                 ),
//                 _Legend(
//                   color: Colors.orange,
//                   label: "T - Travel",
//                   isDesktop: isDesktop,
//                 ),
//                 _Legend(
//                   color: Colors.blue,
//                   label: "O - Onsite",
//                   isDesktop: isDesktop,
//                 ),
//               ],
//             ),
//             SizedBox(height: spacing * 1.5),

//             /// MARK ATTENDANCE
//             Text(
//               "Mark Attendance (Demo)",
//               style: TextStyle(
//                 fontSize: isDesktop ? 20 : 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: spacing / 2),
//             Wrap(
//               spacing: spacing,
//               runSpacing: spacing / 2,
//               children: [
//                 _markButton(
//                   context,
//                   "P",
//                   Colors.green,
//                   AttendanceType.present,
//                   isDesktop,
//                 ),
//                 _markButton(
//                   context,
//                   "A",
//                   Colors.red,
//                   AttendanceType.absent,
//                   isDesktop,
//                 ),
//                 _markButton(
//                   context,
//                   "T",
//                   Colors.orange,
//                   AttendanceType.travel,
//                   isDesktop,
//                 ),
//                 _markButton(
//                   context,
//                   "O",
//                   Colors.blue,
//                   AttendanceType.onsite,
//                   isDesktop,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _markButton(
//     BuildContext context,
//     String label,
//     Color color,
//     AttendanceType type,
//     bool isDesktop,
//   ) {
//     return ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         padding: EdgeInsets.symmetric(
//           horizontal: isDesktop ? 24 : 16,
//           vertical: isDesktop ? 16 : 12,
//         ),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//       onPressed: () {
//         context.read<AttendanceProvider>().markAttendance(selectedDay, type);
//       },
//       child: Text(
//         label,
//         style: TextStyle(
//           fontSize: isDesktop ? 18 : 14,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Color _getColor(AttendanceType type) {
//     switch (type) {
//       case AttendanceType.present:
//         return Colors.green;
//       case AttendanceType.absent:
//         return Colors.red;
//       case AttendanceType.travel:
//         return Colors.orange;
//       case AttendanceType.onsite:
//         return Colors.blue;
//     }
//   }

//   Widget _dayCell(String text, Color color, bool isDesktop) {
//     return Container(
//       margin: EdgeInsets.all(isDesktop ? 6 : 4),
//       width: isDesktop ? 40 : 32,
//       height: isDesktop ? 40 : 32,
//       decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//       alignment: Alignment.center,
//       child: Text(
//         text,
//         style: TextStyle(color: Colors.white, fontSize: isDesktop ? 16 : 12),
//       ),
//     );
//   }
// }

// /// LEGEND WIDGET
// class _Legend extends StatelessWidget {
//   final Color color;
//   final String label;
//   final bool isDesktop;

//   const _Legend({
//     required this.color,
//     required this.label,
//     required this.isDesktop,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: isDesktop ? 16 : 12,
//           height: isDesktop ? 16 : 12,
//           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//         ),
//         SizedBox(width: isDesktop ? 8 : 6),
//         Text(label, style: TextStyle(fontSize: isDesktop ? 16 : 12)),
//       ],
//     );
//   }
// }
