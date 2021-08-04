
import React, { useState, useRef } from 'react';
import NftInterface from "./NftInterface";

function App() {
  const [todos, setTodos] = useState([])

  return (
    <>
      <NftInterface todos={todos}/>
      <input type="text" />
      <button onClick={handleAddTodo}> Add Todo </button>
      <button> Clear Completed Todos </button>
      <div> 0 left to do </div>
    </>
  );
}

export default App;
