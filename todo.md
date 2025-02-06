# Atomic Steps to Implement TikTok-Style Comments in a Swift + Firebase App

## 1. Plan Your Data Structure
- [x] Decide where to store comments
  - Comments will be stored in a top-level "comments" collection in Firestore.
  - Each comment will have postId, userId, content, and created_at.
  - User profile data (photoURL, displayName) will be fetched separately.

- [x] Understand how comments are retrieved
  - To get all comments for a post, query Firestore using where postId = selectedPostId.
  - To show real-time updates, listen for Firestore changes.

## 2. Create the Backend (FirebaseManager)
### 2.1 Set Up Firestore Collection for Comments
- [x] Create a "comments" collection in Firestore.
- [x] Set up comment structure with:
  - postId → Identifies which post this comment belongs to.
  - userId → Identifies who posted the comment.
  - content → The actual comment text.
  - created_at → Timestamp of when the comment was created.

#### Firestore Structure Example:
```
Firestore
 ├── posts
 │    ├── post1
 │    ├── post2
 │
 ├── comments
 │    ├── comment1 { postId: "post1", userId: "user123", content: "Nice!", created_at: TIMESTAMP }
 │    ├── comment2 { postId: "post1", userId: "user456", content: "Awesome!", created_at: TIMESTAMP }
 │
 ├── users
 │    ├── user123 { displayName: "John Doe", photoURL: "https://..." }
 │    ├── user456 { displayName: "Jane Smith", photoURL: "https://..." }
```

### 2.2 Implement Firestore Functions
- [x] Write functions to interact with Firestore:
  #### Add a comment
  - [x] Take userId, postId, content.
  - [x] Save the comment to Firestore.
  - [x] Use Firestore's serverTimestamp() to set created_at.

  #### Fetch comments for a post
  - [x] Query Firestore where postId = selectedPostId.
  - [x] Sort by created_at in ascending order.

  #### Listen for real-time updates
  - [x] Use Firestore's snapshot listener to update the UI whenever a new comment is added.

  #### Fetch user profile
  - [x] Query Firestore using userId from the comment.
  - [x] Retrieve displayName and photoURL.

## 3. Build the Frontend (SwiftUI UI)
### 3.1 Create a Comment ViewModel
- [x] Create a ViewModel to manage comment-related logic:
  - [x] Store the list of comments.
  - [x] Fetch comments when the UI appears.
  - [x] Listen for real-time updates (if enabled).
  - [x] Handle posting new comments.
  - [x] Manage user profiles for comments.
  - [x] Handle error states.

### 3.2 Design the Comment UI
- [ ] Display a "Comments" button in the Feed:
  - [ ] Add a button below the like button to open the comments section.
  - [ ] When tapped, show a bottom sheet (modal view).

- [ ] Inside the Bottom Sheet:
  #### Show a list of comments
  - [ ] Fetch comments for the selected post.
  - [ ] Sort by created_at (oldest to newest).
  - [ ] Display each comment's text and user info.

  #### Display user profile picture
  - [ ] For each comment, fetch photoURL from Firestore.
  - [ ] Show a circular profile picture beside the comment.

  #### Add a text field for new comments
  - [ ] Allow users to type a comment.
  - [ ] Show a "Send" button.
  - [ ] When tapped, call Firestore to save the comment.

## 4. Connect the UI to Firestore
### 4.1 Load Comments When the Bottom Sheet Opens
- [ ] When the user taps the "Comments" button:
  - Open the bottom sheet.
  - Fetch comments for the post.
  - Display them in a list.
  - Fetch and display each comment's user profile picture.
  - If real-time updates are enabled, start a Firestore listener.

### 4.2 Post a New Comment
- [ ] When the user types and presses "Send":
  - Get the userId of the logged-in user.
  - Get the postId of the post being commented on.
  - Save the comment to Firestore.
  - If using real-time updates, the UI will refresh automatically.
  - If not, manually refresh the comments list.

## 5. Test the System
### Ensure Comments Work as Expected
- [ ] Open a post and add a comment.
- [ ] Check Firestore to see if the comment is saved correctly.
- [ ] Verify that the comment appears in the app.
- [ ] Close and reopen the app to ensure comments persist.

### Test Real-Time Updates
- [ ] Open the app on two devices.
- [ ] Post a comment on one device.
- [ ] Check if it appears on the second device without refreshing.

### Check User Profile Fetching
- [ ] Ensure profile pictures and display names load properly.
- [ ] Change a user's profile picture and verify it updates in the comments section.

## Final Checklist
- [ ] Firestore "comments" collection set up
- [ ] Firebase functions implemented (add, fetch, observe comments)
- [ ] SwiftUI UI for bottom sheet and comments list
- [ ] Profile pictures fetched dynamically
- [ ] New comments are added and displayed properly
- [ ] Real-time updates work as expected