ReCode Development Report


Welcome to the documentation pages of ReCode!


This Software Development Report, tailored for LEIC-ES-2024-25, provides comprehensive details about ReCode, from high-level vision to low-level implementation decisions. It’s organised by the following activities.


* [Business modeling](#Business-Modelling)
  * [Product Vision](#Product-Vision)
  * [Features and Assumptions](#Features-and-Assumptions)
  * [Elevator Pitch](#Elevator-pitch)
* [Requirements](#Requirements)
  * [User stories](#User-stories)
  * [Domain model](#Domain-model)
* [Architecture and Design](#Architecture-And-Design)
  * [Logical architecture](#Logical-Architecture)
  * [Physical architecture](#Physical-Architecture)
  * [Vertical prototype](#Vertical-Prototype)
* [Project management](#Project-Management)
  * [Sprint 0](#Sprint-0)
  * [Sprint 1](#Sprint-1)
  * [Sprint 2](#Sprint-2)
  * [Sprint 3](#Sprint-3)
  * [Sprint 4](#Sprint-4)
  * [Final Release](#Final-Release)


Contributions are expected to be made exclusively by the initial team, but we may open them to the community, after the course, in all areas and topics: requirements, technologies, development, experimentation, testing, etc.


Please contact us!


Thank you!


* Gonçalo Calvo up202307459@up.pt
* Fernando Oliveira, up201005231@up.pt
* António Braga, up20170895@up.pt
* Tiago Cunha, up202305564@up.pt
* Tommaso Cambursano, up202411502@up.pt


## Business Modelling

With ReCode, we aim to support students and IT professionals who need to learn and retain knowledge of multiple programming languages efficiently. In a world where developers frequently switch between languages like Python, Java, JavaScript, C++, and SQL, mastering syntax, concepts, and best practices can be overwhelming.
ReCode is designed as an interactive learning platform memory-enhancing techniques to help users internalize programming concepts in a fun and engaging way.Whether you're a student building your foundational skills or a professional refreshing your knowledge, ReCode ensures that programming principles remain sharp and accessible.

### Product Vision

ReCode empowers programmers to seamlessly revisit, compare, and share knowledge of multiple programming languages — turning past learning into future mastery.
helps programmers not be limited by their oversights

### Features and Assumptions

- **Code Snippet Storage & Review** - Store, organize, and revisit old code snippets from past courses or personal projects.
- **Notes with Image Support** - Enrich notes with images, for better understanding and future reference.
- **Quick Reference Guide** - Access a compact guide with syntax and key concepts of various programming languages for fast knowledge refresh.
- **Side-by-Side Language Comparison** - Compare two programming languages directly to see syntax, structures, and conceptual differences.
- **Community Sharing Tab** - Share code snippets, notes, and interact with the community to help others and grow the platform’s collective knowledge base.
- **Community Q&A Tab** - Post questions and contribute answers to help solve programming challenges collaboratively.
- **Language Transition Recommendations** - Receive tailored recommendations, tips, and common pitfalls when switching or learning a new programming language.

### Elevator Pitch

ReCode is a web platform designed to help programmers, students, and developers revisit and reinforce their programming knowledge. It provides a personal library to store code snippets, create notes with images, and access quick reference guides for various languages. With side-by-side language comparisons and AI-driven transition recommendations, ReCode makes relearning seamless. Users can also share knowledge, ask questions, and grow through an active community, making ReCode the perfect companion for continuous learning and skill improvement in programming.

## Requirements

### User Stories

1. [Code Snippet Storage and Review](https://github.com/LEIC-ES-2024-25/2LEIC11T3/issues/6)  
2. [Noting Section with Image Support](https://github.com/LEIC-ES-2024-25/2LEIC11T3/issues/5)  
3. [Quick Reference Guide](https://github.com/LEIC-ES-2024-25/2LEIC11T3/issues/4)  
4. [Side-by-Side Language Comparison](https://github.com/LEIC-ES-2024-25/2LEIC11T3/issues/3)  
5. [Community Section for Questions and Answers](https://github.com/LEIC-ES-2024-25/2LEIC11T3/issues/2)  
6. [Community Tab for Sharing Code Snippets](https://github.com/LEIC-ES-2024-25/2LEIC11T3/issues/1)  
7. [Recommendation Notes for Language Transition](https://github.com/LEIC-ES-2024-25/2LEIC11T3/issues/7)  

### Domain model

<img src="/images/DomainDiagram.png">

- **User**: Represents a user of the application, identified by a username and email. Users can create notes, write comments, receive recommendations, and know different languages.

- **CodeSnippet**: A snippet of code stored in the app, including a description and the date it was created. It is associated with a specific language and can be included in community posts.

- **Note**: A personal note created by a user, containing a title, textual content, and optional images. Notes can include multiple code snippets.

- **ReferenceGuide**: A guide containing various examples related to programming concepts, users can query for learning purposes.

- **CommunityPost**: A post shared within the community, containing a title, content, and a posting date. It can include a code snippet, is authored by a user, and receives comments.

- **Comment**: A user-written response to a community post, containing content and the date it was posted.

- **Recommendation**: A language learning suggestion provided to a user, specifying a translation from one language to another and highlighting key focus areas.

- **Language**: Represents a programming language, including its name and a list of key concepts. Users can have knowledge of multiple languages, and code snippets are written in a specific language.

## Architecture and Design
### Logical architecture

<img src="/images/Logical.png">
The system is structured into several high-level components that work together to provide the functionality outlined in the project goals. These components are divided into four main packages: **User Management**, **Content**, **Community**, and **Language Resources**.

### 1. **User Management**
Focuses on managing the user interactions within the system.
- **User**: Represents individual users who interact with the system, allowing them to store and manage code snippets, create notes, and interact with the community.
- **Recommendation**: Users receive recommendations for transitioning between programming languages.
**Interrelations**:
- The **User** class can create **CodeSnippet**, **Note**, and query the **ReferenceGuide**.
- Users are also able to write **CommunityPost** and contribute to the community via **Comment**.

### 2. **Content**
Manages all the content created and stored within the application.
- **Note**: Users can store notes related to different programming languages, including text and images.
- **CodeSnippet**: Represents code snippets stored by the user for future reference.
- **ReferenceGuide**: Contains a quick reference guide for programming languages, summarizing key syntax and concepts.
**Interrelations**:
- The **Content** package is directly linked to the **User Management** package, as users create and query notes, snippets, and reference guides.
- The **CodeSnippet** is tied to **Language** as it is written in a specific programming language.
 
### 3. **Community**
Handles all the social aspects of the application.
- **CommunityPost**: Users can share their code snippets and notes in the community to help others.
- **Comment**: Users can comment on community posts to engage with other users.
**Interrelations**:
- The **Community** package is connected to the **User Management** package, as users can author posts and comments.
- The **CommunityPost** class can contain **CodeSnippet** and be related to **Recommendation** to provide context for language transitions.

### 4. **Language Resources**
Focuses on the resources related to the programming languages supported by the app.
- **Language**: Represents a programming language.
**Interrelations**:
- The **Language** class is directly linked to **Content** as code snippets and notes are tied to specific languages.

### Physical architecture
<img src="/images/Physical.png">

### Vertical prototype


## Project management


### Sprint 0
Screenshot of our sprint 0 backlog:
<img src="/images/BacklogSprint0.png">


### Sprint 1
Screenshot of our backlog at the beggining of sprint 1:
<img src="/images/BacklogSprint1Beggining.png">

Sprint Retrospective:

Screenshot of our backlog at the end of sprint 1:
<img src="/images/BacklogSprint1End.png">


### Sprint 2


### Sprint 3


### Sprint 4


### Final Release
