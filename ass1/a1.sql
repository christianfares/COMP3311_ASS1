-- COMP3311 18s1 Assignment 1
-- Written by CHRISTIAN_FARES (z5116082), April 2018

-- View used to get id of students who have completed more that 65 courses. Used for Q1.
create or replace view many_courses(student, course_count)
as
	select student, count(student)
	from course_enrolments
	group by student
	having count(student) > 65
;

-- Views used to get the number of students, staff or both. Used in Q2.
create or replace view studentsCount(nstudents)
as
	select count(id) from students 
	where students.id not in (select id from staff)
;

create or replace view staffCount(nstaff)
as
	select count(id) from staff 
	where staff.id not in (select id from students)
;

create or replace view bothCount(nboth)
as
	select count(id) from students 
	where students.id in (select id from staff)
;

-- View to get the id of staff who has been LIC for most courses, and the number of courses. Used for Q3.
create or replace view LIC_COUNT(staff, courseCount)
as
	select staff, count(staff) from course_staff
	where role in (select id from staff_roles where name ~ 'Course Convenor')
	group by course_staff.staff
	order by count(staff) desc
	limit 1
;

-- View to get 05S2 id
create or replace view sem05S2 (semester)
as
	select id from semesters 
	where year = 2005 and term ~* 'S2'
;

-- View to get enrolments in 3978 is 05s2. Used for Q4a.
create or replace view enrolments05s2a (student)
as
	select student from program_enrolments
	where semester in
	(select * from sem05S2)
	and program in
	(select id from programs where code ~ '^3978$')
;

-- Views used to get students in SENGA1 stream 05S2. Used for Q4b.
create or replace view SENGA1enrolments(enrolments)
as
	select partof from stream_enrolments
	where stream in
	(select id from streams where code ~ 'SENGA1')
;

create or replace view SENGA105S2stu(students)
as
	select student from program_enrolments
	where semester in
	(select * from sem05S2)
	and program_enrolments.id in
	(select * from SENGA1enrolments)
;

-- Views to get students in CSE degrees in 05S2. Used for Q4c.
create or replace view CSEprograms (programs) 
as
	select id from programs
	where offeredby in 
	(select id from orgunits where unswid ~ 'COMPSC')
;

create or replace view CSEenrols05S2 (students)
as
	select student from program_enrolments
	where semester in 
	(select * from sem05S2)
	and program_enrolments.program in 
	(select * from CSEprograms)
;

-- Views to get all committees and then the faculty of the committees. Used fro Q5.
create or replace view getCommittees(id)
as
	select id from orgunits
	where utype in
	(select id from orgunit_types where name ~* 'committee')
;

create or replace view getFacultyOf(faculty, number)
as
	select facultyof(id) as faculty, count(facultyof(id)) as number
	from orgunits
	where id in
	(select * from getCommittees)
	group by faculty
	order by number desc
	limit 1
;

-- View to get all the course convenors. Used for Q7.
create or replace view allConvenors(code, year, term, staff) as
	select subjects.code, semesters.year, semesters.term, course_staff.staff
	from courses
	inner join course_staff on courses.id = course_staff.course
	inner join subjects on courses.subject = subjects.id
	inner join semesters on courses.semester = semesters.id
	where course_staff.role in
	(select id from staff_roles where name ~ 'Course Convenor')
;

-- Q1: ...

create or replace view Q1(unswid, name)
as
	select unswid, name from People
	where id in (select student from many_courses)
;

-- Q2: ...

create or replace view Q2(nstudents, nstaff, nboth)
as
	select nstudents, nstaff, nboth
	from studentsCount, staffCount, bothCount
;

-- Q3: ...

create or replace view Q3(name, ncourses)
as
	select people.name as name, lic_count.courseCount as ncourses
	from people
	inner join lic_count on people.id = lic_count.staff
;

-- Q4: ...

create or replace view Q4a(id)
as
	select unswid as id
	from people
	where people.id in
	(select * from enrolments05s2a)
;

create or replace view Q4b(id)
as
	select unswid as id
	from people
	where people.id in 
	(select * from SENGA105S2stu)
;

create or replace view Q4c(id)
as
	select unswid as id
	from people
	where people.id in 
	(select * from CSEenrols05S2)
;

-- Q5: ...

create or replace view Q5(name)
as
	select name from orgunits
	where orgunits.id in
	(select faculty from getFacultyOf)
;

-- Q6: ...

create or replace function Q6(integer) returns text
as
$$
	select name from people where id = $1 or unswid = $1;
$$ language sql
;

-- Q7: ...

create or replace function Q7(text)
	returns table (course text, year integer, term text, convenor text)
as $$
	select cast(allConvenors.code as text) as course, allConvenors.year, cast(allConvenors.term as text), cast(people.name as text) as convenor
	from allConvenors
	inner join people on allConvenors.staff = people.id
	where allConvenors.code ~ $1;
$$ language sql
;

-- Q8: ...

create or replace function Q8(integer)
	returns setof NewTranscriptRecord
as $$
declare
	newRec NewTranscriptRecord;
	sid integer := $1;
	semYear courseYearType;
	semTerm char(2);
	semid integer;
	progid integer;
	x integer;
begin
-- Taken from transcript(integer) function 
	select s.id into x
	from   Students s join People p on (s.id = p.id)
	where  p.unswid = sid;
	if (not found) then
		raise EXCEPTION 'Invalid student %',sid;
	end if;
	for newRec in 
		select 
			oldRec.code,
			oldRec.term,
			null,
			oldRec.name,
			oldRec.mark,
			oldRec.grade,
			oldRec.uoc
		from transcript(sid) oldRec
	loop
		if (newRec.code is not null) then
			semYear := (20||substr(newRec.term, 1,2))::courseYearType;
			semTerm := upper(substr(newRec.term, 3,2));
			
			select program into progid
			from program_enrolments progE
			where progE.student = x and progE.semester in 
				(select sem.id
				from semesters sem
				where sem.year = semYear and sem.term = semTerm);

			select p.code into newRec.prog
			from programs p
			where p.id = progid;
		else
			newRec.prog := null;
		end if;
		return next newRec;
	end loop;
end;
$$ language plpgsql
;


-- Q9: ...

create or replace function Q9(integer)
	returns setof AcObjRecord
as $$
declare
	... PLpgSQL variable delcarations ...
begin
	... PLpgSQL code ...
end;
$$ language plpgsql
;

