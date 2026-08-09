# Tournament Integration Plan

## Overview
Build a full tournament module for JC Sports Hub Inter-Course Tournament 2026/2027.

## Firestore Structure
```
tournaments/{tournamentId}
  name, season, status, dates, courses[], games[], createdBy

tournamentSquads/{tournamentId}/{course}/{game}/{studentId}
  studentId, studentName, studentNumber, registeredAt

tournamentFixtures/{tournamentId}/{game}/{fixtureId}
  round, stage, date, homeCourse, awayCourse, result, homePts, awayPts

tournamentPoints/{tournamentId}/{course}
  gamePoints map, spiritPoints, totalPoints, rank
```

## Models
- TournamentModel
- TournamentSquad
- TournamentFixture
- TournamentPoints

## Services
- TournamentService (CRUD, squad registration, fixture generation)
- Points calculation logic

## Admin Panel
- New Tournaments tab
- Create tournament form
- Auto-generate fixtures from Excel data
- Squad registration view
- Result input per match
- Auto Master Points Table

## Student View
- Tournaments tab in sidebar
- Upcoming/Ongoing/Completed
- Per-game fixtures with icons
- Points table per course
- Overall championship standings

## Notifications
- Auto-notify on tournament creation
- Registration deadline reminder
- Match day reminder
- Results posted

## Game Icons
- Football: Icons.sports_soccer
- Netball: Icons.sports_basketball (or custom)
- Volleyball: Icons.sports_volleyball
- Chess: Icons.public (or custom)
- Scrabble: Icons.text_fields
- Ludo: Icons.casino
- Matatu/Cards: Icons.directions_car
